import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../models/assignable_exercise.dart';
import '../../../models/training_session_result.dart';
import '../evaluation/pose_evaluation_session.dart';
import '../repositories/training_result_repository.dart';
import 'training_session_state_machine.dart';

enum TrainingResultSubmissionStatus { idle, submitting, saved, failed }

class PoseTrainingSessionController {
  PoseTrainingSessionController({
    required ValueListenable<PoseEvaluationSnapshot> evaluation,
    required this.exercise,
    required this.repository,
    required TrainingSessionConfig config,
    DateTime Function()? wallClock,
    Duration Function()? elapsedProvider,
    String Function()? sessionIdFactory,
  })  : _evaluation = evaluation,
        _machine = TrainingSessionStateMachine(config),
        _wallClock = wallClock ?? DateTime.now,
        _elapsedProvider = elapsedProvider,
        _sessionIdFactory = sessionIdFactory ?? _newSessionId,
        snapshot = ValueNotifier(TrainingSessionStateMachine(config).snapshot),
        submission = ValueNotifier(TrainingResultSubmissionStatus.idle) {
    _evaluation.addListener(_onEvaluation);
    start();
  }

  final ValueListenable<PoseEvaluationSnapshot> _evaluation;
  final AssignableExercise exercise;
  final TrainingResultRepository repository;
  final TrainingSessionStateMachine _machine;
  final DateTime Function() _wallClock;
  final Duration Function()? _elapsedProvider;
  final Stopwatch _stopwatch = Stopwatch();
  final String Function() _sessionIdFactory;
  final ValueNotifier<TrainingSessionSnapshot> snapshot;
  final ValueNotifier<TrainingResultSubmissionStatus> submission;

  late String _sessionId;
  late DateTime _startedAt;
  TrainingSessionResult? _pendingResult;
  bool _submissionInFlight = false;
  bool _disposed = false;

  void start() {
    if (_disposed) return;
    _sessionId = _sessionIdFactory();
    _startedAt = _wallClock().toUtc();
    _pendingResult = null;
    _submissionInFlight = false;
    submission.value = TrainingResultSubmissionStatus.idle;
    _stopwatch
      ..reset()
      ..start();
    snapshot.value = _machine.start();
  }

  void reset() => start();

  void beginNextSet() {
    if (_disposed) return;
    snapshot.value = _machine.beginNextSet();
  }

  Future<void> retrySubmission() async {
    if (_pendingResult != null && !_submissionInFlight) {
      await _submitOnce(_pendingResult!);
    }
  }

  void _onEvaluation() {
    if (_disposed) return;
    final next = _machine.update(
      _evaluation.value.evaluation.presentedOverallStatus,
      _elapsed,
    );
    snapshot.value = next;
    if (next.isCompleted && _pendingResult == null) {
      _stopwatch.stop();
      final completedAt = _wallClock().toUtc();
      _pendingResult = TrainingSessionResult(
        sessionId: _sessionId,
        exerciseType: exercise.type,
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        completedSets: next.targetSets,
        completedReps: next.completedReps,
        targetSets: next.targetSets,
        targetReps: next.targetReps,
        startedAt: _startedAt,
        completedAt: completedAt,
        durationSeconds: max(0, _elapsed.inSeconds),
        status: TrainingCompletionStatus.completed,
        score: next.score,
      );
      _submitOnce(_pendingResult!);
    }
  }

  Future<void> _submitOnce(TrainingSessionResult result) async {
    if (_submissionInFlight ||
        submission.value == TrainingResultSubmissionStatus.saved) {
      return;
    }
    _submissionInFlight = true;
    submission.value = TrainingResultSubmissionStatus.submitting;
    try {
      await repository.save(result);
      if (!_disposed) submission.value = TrainingResultSubmissionStatus.saved;
    } on Object {
      if (!_disposed) submission.value = TrainingResultSubmissionStatus.failed;
    } finally {
      _submissionInFlight = false;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stopwatch.stop();
    _evaluation.removeListener(_onEvaluation);
    snapshot.dispose();
    submission.dispose();
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

  Duration get _elapsed => _elapsedProvider?.call() ?? _stopwatch.elapsed;
}
