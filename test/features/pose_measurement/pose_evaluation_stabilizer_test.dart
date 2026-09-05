import 'package:flutter_body/features/pose_measurement/evaluation/pose_evaluation_result.dart';
import 'package:flutter_body/features/pose_measurement/evaluation/pose_evaluation_stabilizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requires three pass frames before presenting correct', () {
    final stabilizer = PoseEvaluationStabilizer();
    expect(stabilizer.update(PoseOverallEvaluationStatus.correct),
        PoseOverallEvaluationStatus.unavailable);
    expect(stabilizer.update(PoseOverallEvaluationStatus.correct),
        PoseOverallEvaluationStatus.unavailable);
    expect(stabilizer.update(PoseOverallEvaluationStatus.correct),
        PoseOverallEvaluationStatus.correct);
  });

  test('single failure does not flip correct; sustained failure does', () {
    final stabilizer = PoseEvaluationStabilizer();
    for (var i = 0; i < 3; i++) {
      stabilizer.update(PoseOverallEvaluationStatus.correct);
    }
    expect(stabilizer.update(PoseOverallEvaluationStatus.needsAdjustment),
        PoseOverallEvaluationStatus.correct);
    expect(stabilizer.update(PoseOverallEvaluationStatus.correct),
        PoseOverallEvaluationStatus.correct);
    for (var i = 0; i < 3; i++) {
      stabilizer.update(PoseOverallEvaluationStatus.needsAdjustment);
    }
    expect(stabilizer.presented, PoseOverallEvaluationStatus.needsAdjustment);
  });

  test('sustained unavailable clears previous correct', () {
    final stabilizer = PoseEvaluationStabilizer();
    for (var i = 0; i < 3; i++) {
      stabilizer.update(PoseOverallEvaluationStatus.correct);
    }
    for (var i = 0; i < 2; i++) {
      expect(stabilizer.update(PoseOverallEvaluationStatus.unavailable),
          PoseOverallEvaluationStatus.correct);
    }
    expect(stabilizer.update(PoseOverallEvaluationStatus.unavailable),
        PoseOverallEvaluationStatus.unavailable);
  });

  test('alternating candidates do not accumulate', () {
    final stabilizer = PoseEvaluationStabilizer();
    stabilizer.update(PoseOverallEvaluationStatus.correct);
    stabilizer.update(PoseOverallEvaluationStatus.needsAdjustment);
    stabilizer.update(PoseOverallEvaluationStatus.correct);
    expect(stabilizer.presented, PoseOverallEvaluationStatus.unavailable);
  });

  test('reset clears prior session and no-rules is immediate', () {
    final stabilizer = PoseEvaluationStabilizer();
    for (var i = 0; i < 3; i++) {
      stabilizer.update(PoseOverallEvaluationStatus.correct);
    }
    stabilizer.reset();
    expect(stabilizer.presented, PoseOverallEvaluationStatus.unavailable);
    expect(stabilizer.update(PoseOverallEvaluationStatus.correct),
        PoseOverallEvaluationStatus.unavailable);
    stabilizer.reset(hasRules: false);
    expect(stabilizer.presented, PoseOverallEvaluationStatus.noRules);
    expect(stabilizer.update(PoseOverallEvaluationStatus.noRules),
        PoseOverallEvaluationStatus.noRules);
  });
}
