import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../models/assignable_exercise.dart';
import '../../../models/custom_rehab_exercise.dart';
import '../../../models/pose_data.dart';
import '../../../models/training_session_result.dart';
import '../../pose_measurement/evaluation/pose_evaluation_result.dart';
import '../../pose_measurement/repositories/training_result_repository.dart';
import '../../pose_measurement/training/training_session_state_machine.dart';
import 'custom_exercise_pose_evaluator.dart';
import 'custom_exercise_pose_features.dart';
import 'custom_exercise_pose_reference.dart';

enum CustomExerciseTrainingPhase {
  preparing,
  tracking,
  matchingKeyframe,
  holding,
  repetitionCompleted,
  resting,
  switchingCamera,
  paused,
  completed,
}

enum CustomExerciseResultSubmissionStatus { idle, submitting, saved, failed }

class CustomExerciseTrainingSnapshot {
  const CustomExerciseTrainingSnapshot({
    required this.phase,
    required this.currentKeyframeIndex,
    required this.keyframeCount,
    required this.currentRep,
    required this.currentSet,
    required this.completedReps,
    required this.targetReps,
    required this.targetSets,
    required this.holdElapsed,
    required this.holdDuration,
    required this.restRemaining,
    required this.matchScore,
    required this.feedback,
    required this.submissionStatus,
  });

  final CustomExerciseTrainingPhase phase;
  final int currentKeyframeIndex;
  final int keyframeCount;
  final int currentRep;
  final int currentSet;
  final int completedReps;
  final int targetReps;
  final int targetSets;
  final Duration holdElapsed;
  final Duration holdDuration;
  final Duration restRemaining;
  final double matchScore;
  final String feedback;
  final CustomExerciseResultSubmissionStatus submissionStatus;

  bool get isCompleted => phase == CustomExerciseTrainingPhase.completed;
}

/// Pure timestamp-driven CUSTOM exercise sequence controller.
///
/// Camera and RTMPose ownership stay outside this class. It consumes normalized
/// angular features, advances ordered therapist keyframes after a stable match,
/// and delegates hold/repetition/set anti-double-count semantics to the existing
/// training state machine.
class CustomExerciseTrainingController extends ChangeNotifier {
  CustomExerciseTrainingController({
    required this.exercise,
    required this.repository,
    CustomExercisePoseReferenceBuilder referenceBuilder =
        const CustomExercisePoseReferenceBuilder(),
    this.featureExtractor = const CustomPoseFeatureExtractor(),
    this.evaluator = const CustomExercisePoseEvaluator(),
    this.stableMatchDuration = const Duration(milliseconds: 300),
    DateTime Function()? wallClock,
    String Function()? sessionIdFactory,
  })  : _references = referenceBuilder.build(exercise),
        _wallClock = wallClock ?? DateTime.now,
        _sessionIdFactory = sessionIdFactory ?? _newSessionId,
        _machine = TrainingSessionStateMachine(
          TrainingSessionConfig(
            targetReps: exercise.repetitions,
            targetSets: exercise.sets,
            holdDuration: Duration(
              milliseconds: (exercise.holdSeconds * 1000).round(),
            ),
          ),
        ) {
    _startedAt = _wallClock().toUtc();
    _sessionId = _sessionIdFactory();
    _machine.start();
  }

  final CustomRehabExercise exercise;
  final TrainingResultRepository repository;
  final CustomPoseFeatureExtractor featureExtractor;
  final CustomExercisePoseEvaluator evaluator;
  final Duration stableMatchDuration;
  final List<CustomExercisePoseReference> _references;
  final TrainingSessionStateMachine _machine;
  final DateTime Function() _wallClock;
  final String Function() _sessionIdFactory;

  late DateTime _startedAt;
  late String _sessionId;
  Duration _elapsed = Duration.zero;
  Duration? _stableSince;
  Duration? _restUntil;
  bool _waitingForRelease = false;
  bool _switchingCamera = false;
  bool _paused = false;
  bool _disposed = false;
  bool _submissionInFlight = false;
  int _currentKeyframeIndex = 0;
  double _matchScore = 0;
  String _feedback = '請讓完整身體進入畫面';
  CustomExerciseTrainingPhase _phase = CustomExerciseTrainingPhase.preparing;
  CustomExerciseResultSubmissionStatus _submissionStatus =
      CustomExerciseResultSubmissionStatus.idle;

  bool get hasUsableReferences => _references.length >= 2;

  CustomExerciseTrainingSnapshot get snapshot {
    final training = _machine.snapshot;
    return CustomExerciseTrainingSnapshot(
      phase: _phase,
      currentKeyframeIndex: _currentKeyframeIndex,
      keyframeCount: _references.length,
      currentRep: training.currentRep,
      currentSet: training.currentSet,
      completedReps: training.completedReps,
      targetReps: training.targetReps,
      targetSets: training.targetSets,
      holdElapsed: training.holdElapsed,
      holdDuration: training.holdDuration,
      restRemaining: _restRemaining,
      matchScore: _matchScore,
      feedback: _feedback,
      submissionStatus: _submissionStatus,
    );
  }

  void markReady() {
    if (_disposed || _phase != CustomExerciseTrainingPhase.preparing) return;
    _phase = CustomExerciseTrainingPhase.tracking;
    _feedback =
        hasUsableReferences ? '請依序完成畫面中的動作姿勢' : '此自訂動作至少需要 2 個 Keyframes 才能訓練';
    notifyListeners();
  }

  void processPose(PoseData pose, Duration elapsed) {
    processFeatures(featureExtractor.fromPoseData(pose), elapsed);
  }

  @visibleForTesting
  void processFeatures(CustomPoseFeatures live, Duration elapsed) {
    if (_disposed ||
        _paused ||
        _switchingCamera ||
        _phase == CustomExerciseTrainingPhase.completed ||
        !hasUsableReferences) {
      return;
    }
    _elapsed = elapsed < _elapsed ? _elapsed : elapsed;

    if (_restUntil != null) {
      if (_elapsed < _restUntil!) {
        _phase = CustomExerciseTrainingPhase.resting;
        notifyListeners();
        return;
      }
      _restUntil = null;
      if (_machine.snapshot.phase == TrainingSessionPhase.setCompleted) {
        _machine.beginNextSet();
      }
      _waitingForRelease = true;
      _phase = CustomExerciseTrainingPhase.tracking;
    }

    if (_waitingForRelease) {
      final finalEvaluation = evaluator.evaluate(_references.last, live);
      _matchScore = finalEvaluation.score;
      if (!finalEvaluation.isAvailable) {
        _feedback = finalEvaluation.feedback;
        notifyListeners();
        return;
      }
      if (finalEvaluation.isMatched) {
        _feedback = '請先回到起始姿勢，再開始下一次';
        notifyListeners();
        return;
      }
      _machine.update(PoseOverallEvaluationStatus.needsAdjustment, _elapsed);
      _waitingForRelease = false;
      _currentKeyframeIndex = 0;
      _stableSince = null;
    }

    final reference = _references[_currentKeyframeIndex];
    final evaluation = evaluator.evaluate(reference, live);
    _matchScore = evaluation.score;

    if (_machine.snapshot.phase == TrainingSessionPhase.holding) {
      final status = !evaluation.isAvailable
          ? PoseOverallEvaluationStatus.unavailable
          : evaluation.isMatched
              ? PoseOverallEvaluationStatus.correct
              : PoseOverallEvaluationStatus.needsAdjustment;
      final before = _machine.snapshot.completedReps;
      _machine.update(status, _elapsed);
      _feedback = evaluation.feedback;
      _phase = _machine.snapshot.phase == TrainingSessionPhase.holding
          ? CustomExerciseTrainingPhase.holding
          : CustomExerciseTrainingPhase.tracking;
      if (_machine.snapshot.completedReps > before) {
        _handleCompletedRep();
      }
      notifyListeners();
      return;
    }

    if (!evaluation.isAvailable || !evaluation.isMatched) {
      _stableSince = null;
      _feedback = evaluation.feedback;
      _phase = CustomExerciseTrainingPhase.tracking;
      notifyListeners();
      return;
    }

    _feedback = evaluation.feedback;
    _stableSince ??= _elapsed;
    if (_elapsed - _stableSince! < stableMatchDuration) {
      _phase = CustomExerciseTrainingPhase.matchingKeyframe;
      notifyListeners();
      return;
    }

    final isFinal = _currentKeyframeIndex == _references.length - 1;
    if (!isFinal) {
      _currentKeyframeIndex++;
      _stableSince = null;
      _phase = CustomExerciseTrainingPhase.tracking;
      _feedback = '姿勢已完成，請進入下一個動作位置';
      notifyListeners();
      return;
    }

    final before = _machine.snapshot.completedReps;
    _machine.update(PoseOverallEvaluationStatus.correct, _elapsed);
    _phase = CustomExerciseTrainingPhase.holding;
    if (_machine.snapshot.completedReps > before) {
      _handleCompletedRep();
    }
    notifyListeners();
  }

  void beginCameraSwitch() {
    if (_disposed || _switchingCamera) return;
    _switchingCamera = true;
    _stableSince = null;
    _machine.cancelActiveHold();
    _phase = CustomExerciseTrainingPhase.switchingCamera;
    _feedback = '正在切換鏡頭…';
    notifyListeners();
  }

  void finishCameraSwitch({required bool success}) {
    if (_disposed || !_switchingCamera) return;
    _switchingCamera = false;
    _phase = CustomExerciseTrainingPhase.tracking;
    _feedback = success ? '鏡頭已切換，請繼續目前動作' : '鏡頭切換失敗，請重試';
    notifyListeners();
  }

  void pause() {
    if (_disposed || _paused || snapshot.isCompleted) return;
    _paused = true;
    _stableSince = null;
    _machine.cancelActiveHold();
    _phase = CustomExerciseTrainingPhase.paused;
    _feedback = '訓練已暫停';
    notifyListeners();
  }

  void resume() {
    if (_disposed || !_paused || snapshot.isCompleted) return;
    _paused = false;
    _phase = CustomExerciseTrainingPhase.tracking;
    _feedback = '請繼續目前動作';
    notifyListeners();
  }

  void _handleCompletedRep() {
    _stableSince = null;
    if (_machine.snapshot.phase == TrainingSessionPhase.completed) {
      _phase = CustomExerciseTrainingPhase.completed;
      _feedback = '訓練完成';
      _submitCompletionOnce();
      return;
    }
    final restDuration = Duration(
      milliseconds: (exercise.restSeconds * 1000).round(),
    );
    _phase = restDuration > Duration.zero
        ? CustomExerciseTrainingPhase.resting
        : CustomExerciseTrainingPhase.repetitionCompleted;
    _feedback = restDuration > Duration.zero
        ? '第 ${_machine.snapshot.currentRep} 次完成，請稍作休息'
        : '第 ${_machine.snapshot.currentRep} 次完成';
    _currentKeyframeIndex = 0;
    _waitingForRelease = true;
    _restUntil = _elapsed + restDuration;
  }

  Future<void> retrySubmission() async {
    if (_phase == CustomExerciseTrainingPhase.completed) {
      await _submitCompletionOnce();
    }
  }

  Future<void> _submitCompletionOnce() async {
    if (_submissionInFlight ||
        _submissionStatus == CustomExerciseResultSubmissionStatus.saved) {
      return;
    }
    _submissionInFlight = true;
    _submissionStatus = CustomExerciseResultSubmissionStatus.submitting;
    notifyListeners();
    final completedAt = _wallClock().toUtc();
    final training = _machine.snapshot;
    final result = TrainingSessionResult(
      sessionId: _sessionId,
      exerciseType: AssignableExerciseType.custom,
      exerciseId: exercise.id,
      exerciseName: exercise.name,
      completedSets: training.targetSets,
      completedReps: training.completedReps,
      targetSets: training.targetSets,
      targetReps: training.targetReps,
      startedAt: _startedAt,
      completedAt: completedAt,
      durationSeconds: max(0, _elapsed.inSeconds),
      status: TrainingCompletionStatus.completed,
      score: training.score,
    );
    try {
      await repository.save(result);
      if (!_disposed) {
        _submissionStatus = CustomExerciseResultSubmissionStatus.saved;
        notifyListeners();
      }
    } on Object {
      if (!_disposed) {
        _submissionStatus = CustomExerciseResultSubmissionStatus.failed;
        notifyListeners();
      }
    } finally {
      _submissionInFlight = false;
    }
  }

  Duration get _restRemaining {
    final until = _restUntil;
    if (until == null || until <= _elapsed) return Duration.zero;
    return until - _elapsed;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static String _newSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final value = bytes.map(hex).join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
