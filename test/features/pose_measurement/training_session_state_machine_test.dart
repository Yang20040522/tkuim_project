import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/features/pose_measurement/evaluation/pose_evaluation_engine.dart';
import 'package:flutter_body/features/pose_measurement/evaluation/pose_evaluation_result.dart';
import 'package:flutter_body/features/pose_measurement/evaluation/pose_evaluation_session.dart';
import 'package:flutter_body/features/pose_measurement/evaluation/pose_measurement_rule.dart';
import 'package:flutter_body/features/pose_measurement/models/joint_angle_frame.dart';
import 'package:flutter_body/features/pose_measurement/repositories/training_result_repository.dart';
import 'package:flutter_body/features/pose_measurement/training/pose_training_session_controller.dart';
import 'package:flutter_body/features/pose_measurement/training/training_session_state_machine.dart';
import 'package:flutter_body/models/assignable_exercise.dart';
import 'package:flutter_body/models/training_session_result.dart';
import 'package:flutter/foundation.dart';

void main() {
  const correct = PoseOverallEvaluationStatus.correct;
  const adjust = PoseOverallEvaluationStatus.needsAdjustment;
  const unavailable = PoseOverallEvaluationStatus.unavailable;

  TrainingSessionStateMachine machine({
    int reps = 2,
    int sets = 1,
    bool autoCount = true,
  }) =>
      TrainingSessionStateMachine(
        TrainingSessionConfig(
          targetReps: reps,
          targetSets: sets,
          holdDuration: const Duration(milliseconds: 1500),
          autoCountEnabled: autoCount,
        ),
      )..start();

  test('CORRECT shorter than hold does not complete a rep', () {
    final subject = machine();
    subject.update(correct, Duration.zero);
    final result = subject.update(correct, const Duration(milliseconds: 1499));
    expect(result.currentRep, 0);
    expect(result.phase, TrainingSessionPhase.holding);
  });

  test('continuous hold completes once and requires release', () {
    final subject = machine();
    subject.update(correct, Duration.zero);
    var result = subject.update(correct, const Duration(milliseconds: 1500));
    expect(result.currentRep, 1);
    expect(result.phase, TrainingSessionPhase.waitingForRelease);

    result = subject.update(correct, const Duration(seconds: 8));
    expect(result.currentRep, 1);
  });

  test('leave target then return and hold completes second rep', () {
    final subject = machine();
    subject.update(correct, Duration.zero);
    subject.update(correct, const Duration(milliseconds: 1500));
    subject.update(adjust, const Duration(seconds: 2));
    subject.update(correct, const Duration(milliseconds: 2100));
    final result = subject.update(correct, const Duration(milliseconds: 3600));
    expect(result.completedReps, 2);
    expect(result.phase, TrainingSessionPhase.completed);
  });

  test('adjustment during hold cancels partial progress', () {
    final subject = machine();
    subject.update(correct, Duration.zero);
    subject.update(correct, const Duration(seconds: 1));
    subject.update(adjust, const Duration(milliseconds: 1100));
    var result = subject.update(adjust, const Duration(milliseconds: 1401));
    expect(result.phase, TrainingSessionPhase.waitingForCorrect);
    expect(result.holdElapsed, Duration.zero);
    result = subject.update(correct, const Duration(milliseconds: 1200));
    result = subject.update(correct, const Duration(milliseconds: 2200));
    expect(result.currentRep, 0);
  });

  test('brief adjustment preserves hold and excludes dropout time', () {
    final subject = machine(reps: 1);
    subject.update(correct, Duration.zero);
    subject.update(correct, const Duration(milliseconds: 800));
    var result = subject.update(adjust, const Duration(milliseconds: 800));
    expect(result.phase, TrainingSessionPhase.holding);
    expect(result.holdElapsed, const Duration(milliseconds: 800));

    result = subject.update(correct, const Duration(milliseconds: 950));
    expect(result.holdElapsed, const Duration(milliseconds: 800));
    result = subject.update(correct, const Duration(milliseconds: 1650));
    expect(result.phase, TrainingSessionPhase.completed);
    expect(result.completedReps, 1);
  });

  test('brief unavailable preserves hold and excludes dropout time', () {
    final subject = machine(reps: 1);
    subject.update(correct, Duration.zero);
    subject.update(correct, const Duration(milliseconds: 900));
    subject.update(unavailable, const Duration(milliseconds: 900));
    var result = subject.update(correct, const Duration(milliseconds: 1100));
    expect(result.phase, TrainingSessionPhase.holding);
    expect(result.holdElapsed, const Duration(milliseconds: 900));

    result = subject.update(correct, const Duration(milliseconds: 1700));
    expect(result.phase, TrainingSessionPhase.completed);
    expect(result.completedReps, 1);
  });

  test('multiple brief dropouts count only continuously correct time', () {
    final subject = machine(reps: 1);
    subject.update(correct, Duration.zero);
    subject.update(correct, const Duration(milliseconds: 400));
    subject.update(adjust, const Duration(milliseconds: 400));
    subject.update(correct, const Duration(milliseconds: 500));
    subject.update(correct, const Duration(milliseconds: 800));
    subject.update(unavailable, const Duration(milliseconds: 800));
    subject.update(correct, const Duration(milliseconds: 1000));

    var result = subject.update(correct, const Duration(milliseconds: 1600));
    expect(result.phase, TrainingSessionPhase.holding);
    expect(result.holdElapsed, const Duration(milliseconds: 1300));
    result = subject.update(correct, const Duration(milliseconds: 1800));
    expect(result.phase, TrainingSessionPhase.completed);
    expect(result.completedReps, 1);
  });

  test('persistent incorrect pose resets hold and cannot complete a rep', () {
    final subject = machine(reps: 1);
    subject.update(correct, Duration.zero);
    subject.update(correct, const Duration(milliseconds: 800));
    subject.update(adjust, const Duration(milliseconds: 800));
    var result = subject.update(adjust, const Duration(milliseconds: 1101));
    expect(result.phase, TrainingSessionPhase.waitingForCorrect);
    expect(result.holdElapsed, Duration.zero);

    result = subject.update(adjust, const Duration(seconds: 5));
    expect(result.completedReps, 0);
  });

  test('reset clears hold and active dropout grace state', () {
    final subject = machine(reps: 1);
    subject.update(correct, Duration.zero);
    subject.update(correct, const Duration(milliseconds: 700));
    subject.update(unavailable, const Duration(milliseconds: 700));

    var result = subject.reset();
    expect(result.phase, TrainingSessionPhase.ready);
    expect(result.holdElapsed, Duration.zero);
    result = subject.start();
    expect(result.phase, TrainingSessionPhase.waitingForCorrect);
    expect(result.completedReps, 0);
  });

  test('UNAVAILABLE during hold never completes or rearms', () {
    final subject = machine();
    subject.update(correct, Duration.zero);
    subject.update(unavailable, const Duration(seconds: 1));
    final result = subject.update(unavailable, const Duration(seconds: 5));
    expect(result.currentRep, 0);
    expect(result.phase, TrainingSessionPhase.waitingForCorrect);
  });

  test('multiple rules with one failure cannot start hold', () {
    const rules = [
      PoseMeasurementRule(
        measurement: JointMeasurementType.leftElbow,
        targetAngleDegrees: 90,
        toleranceDegrees: 10,
      ),
      PoseMeasurementRule(
        measurement: JointMeasurementType.rightElbow,
        targetAngleDegrees: 90,
        toleranceDegrees: 10,
      ),
    ];
    const engine = PoseEvaluationEngine();
    final evaluated = engine.evaluate(
      measurements: JointAngleFrame(
        timestampMs: 1,
        angles: const {
          JointMeasurementType.leftElbow: 90,
          JointMeasurementType.rightElbow: 130,
        },
      ),
      rules: rules,
    );
    final subject = machine();
    final result = subject.update(evaluated.overallStatus, Duration.zero);
    expect(evaluated.overallStatus, adjust);
    expect(result.phase, TrainingSessionPhase.waitingForCorrect);
  });

  test('set transition and final set complete deterministically', () {
    final subject = machine(reps: 1, sets: 2);
    subject.update(correct, Duration.zero);
    var result = subject.update(correct, const Duration(milliseconds: 1500));
    expect(result.phase, TrainingSessionPhase.setCompleted);
    expect(result.currentSet, 1);

    result = subject.beginNextSet();
    expect(result.currentSet, 2);
    expect(result.phase, TrainingSessionPhase.waitingForRelease);
    subject.update(adjust, const Duration(milliseconds: 1600));
    subject.update(correct, const Duration(seconds: 2));
    result = subject.update(correct, const Duration(milliseconds: 3500));
    expect(result.phase, TrainingSessionPhase.completed);
    expect(result.completedReps, 2);
    expect(result.score, 100);
  });

  test('reset clears all counters and completion', () {
    final subject = machine(reps: 1);
    subject.update(correct, Duration.zero);
    subject.update(correct, const Duration(milliseconds: 1500));
    final result = subject.reset();
    expect(result.phase, TrainingSessionPhase.ready);
    expect(result.completedReps, 0);
    expect(result.currentRep, 0);
    expect(result.currentSet, 1);
  });

  test('no-rule session cannot auto-count', () {
    final subject = machine(reps: 1, autoCount: false);
    final result = subject.update(correct, const Duration(minutes: 1));
    expect(result.completedReps, 0);
    expect(result.isCompleted, isFalse);
  });

  test('score stays between zero and one hundred', () {
    final subject = machine(reps: 2, sets: 2);
    expect(subject.snapshot.score, inInclusiveRange(0, 100));
    subject.update(correct, Duration.zero);
    subject.update(correct, const Duration(milliseconds: 1500));
    expect(subject.snapshot.score, 25);
  });

  test('completion callback submits a session only once', () async {
    var elapsed = Duration.zero;
    final evaluation = ValueNotifier(_snapshot(unavailable));
    final repository = _FakeTrainingResultRepository();
    final controller = PoseTrainingSessionController(
      evaluation: evaluation,
      exercise: const AssignableExercise(
        id: 'custom-1',
        name: '手肘訓練',
        description: '',
        type: AssignableExerciseType.custom,
        assigned: true,
      ),
      repository: repository,
      config: TrainingSessionConfig(
        targetReps: 1,
        targetSets: 1,
        holdDuration: const Duration(milliseconds: 1500),
      ),
      elapsedProvider: () => elapsed,
      sessionIdFactory: () => 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    );

    evaluation.value = _snapshot(correct);
    elapsed = const Duration(milliseconds: 1500);
    evaluation.value = _snapshot(correct);
    evaluation.value = _snapshot(correct);
    await Future<void>.delayed(Duration.zero);

    expect(repository.saved, hasLength(1));
    expect(controller.submission.value, TrainingResultSubmissionStatus.saved);
    controller.dispose();
    evaluation.dispose();
  });

  test('no-rule controller never submits a fake successful result', () async {
    var elapsed = Duration.zero;
    final evaluation = ValueNotifier(_snapshot(correct));
    final repository = _FakeTrainingResultRepository();
    final controller = PoseTrainingSessionController(
      evaluation: evaluation,
      exercise: const AssignableExercise(
        id: 'legacy-custom',
        name: '舊自訂動作',
        description: '',
        type: AssignableExerciseType.custom,
        assigned: true,
      ),
      repository: repository,
      config: TrainingSessionConfig(
        targetReps: 1,
        targetSets: 1,
        holdDuration: const Duration(milliseconds: 1500),
        autoCountEnabled: false,
      ),
      elapsedProvider: () => elapsed,
    );

    elapsed = const Duration(minutes: 1);
    evaluation.value = _snapshot(correct);
    await Future<void>.delayed(Duration.zero);

    expect(repository.saved, isEmpty);
    expect(controller.snapshot.value.isCompleted, isFalse);
    controller.dispose();
    evaluation.dispose();
  });

  test('training result JSON response round trip preserves bounded score', () {
    final value = TrainingSessionResult.fromJson({
      'sessionId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'exerciseType': 'CUSTOM',
      'exerciseId': 'custom-1',
      'exerciseName': '手肘訓練',
      'completedSets': 2,
      'completedReps': 6,
      'targetSets': 2,
      'targetReps': 3,
      'startedAt': '2026-09-05T01:00:00Z',
      'completedAt': '2026-09-05T01:01:00Z',
      'durationSeconds': 60,
      'completionStatus': 'COMPLETED',
      'score': 120,
    });
    expect(value.score, 100);
    expect(value.toRequestJson()['exerciseType'], 'CUSTOM');
    expect(value.toRequestJson(), isNot(contains('score')));
  });
}

PoseEvaluationSnapshot _snapshot(PoseOverallEvaluationStatus status) {
  const raw = PoseEvaluationResult(
      rules: [], overallStatus: PoseOverallEvaluationStatus.noRules);
  return PoseEvaluationSnapshot(
    measurements: JointAngleFrame(timestampMs: 0, angles: const {}),
    evaluation: StabilizedPoseEvaluation(
      raw: raw,
      presentedOverallStatus: status,
    ),
    inferenceMs: 0,
  );
}

class _FakeTrainingResultRepository implements TrainingResultRepository {
  final List<TrainingSessionResult> saved = [];

  @override
  Future<TrainingSessionResult> save(TrainingSessionResult result) async {
    saved.add(result);
    return result;
  }

  @override
  Future<List<TrainingSessionResult>> getMyResults() async => saved;

  @override
  Future<List<TrainingSessionResult>> getPatientResults(
          String patientId) async =>
      saved;
}
