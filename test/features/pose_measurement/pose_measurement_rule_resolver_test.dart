import 'package:flutter_body/features/pose_measurement/evaluation/pose_measurement_rule_resolver.dart';
import 'package:flutter_body/features/pose_measurement/models/joint_angle_frame.dart';
import 'package:flutter_body/models/assignable_exercise.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = PoseMeasurementRuleResolver();

  AssignableExercise exercise(String name, AssignableExerciseType type) =>
      AssignableExercise(
        id: 'existing-id',
        name: name,
        description: '',
        type: type,
        assigned: true,
      );

  test('known default elbow exercise resolves deterministic rules', () {
    final rules = resolver.resolve(
      exercise('手肘屈伸訓練', AssignableExerciseType.defaultExercise),
    );
    expect(rules.map((rule) => rule.measurement), [
      JointMeasurementType.leftElbow,
      JointMeasurementType.rightElbow,
    ]);
    expect(rules.every((rule) => rule.targetAngleDegrees == 150), isTrue);
  });

  test('known default sit-to-stand resolves bilateral knee endpoint', () {
    final rules = resolver.resolve(
      exercise(' 坐站 訓練 ', AssignableExerciseType.defaultExercise),
    );
    expect(rules.map((rule) => rule.measurement), [
      JointMeasurementType.leftKnee,
      JointMeasurementType.rightKnee,
    ]);
    expect(rules.every((rule) => rule.targetAngleDegrees == 140), isTrue);
  });

  test('unknown or unsupported default returns empty rules', () {
    expect(
      resolver.resolve(exercise(
        '全身骨架偵測',
        AssignableExerciseType.defaultExercise,
      )),
      isEmpty,
    );
  });

  test('custom exercise never maps GLB-local rule semantics', () {
    expect(
      resolver.resolve(
        exercise('手肘屈伸訓練', AssignableExerciseType.custom),
      ),
      isEmpty,
    );
  });
}
