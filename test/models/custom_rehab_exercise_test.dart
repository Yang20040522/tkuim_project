import 'dart:convert';

import 'package:flutter_body/models/custom_rehab_exercise.dart';
import 'package:flutter_body/models/evaluation_rule.dart';
import 'package:flutter_body/models/exercise_keyframe.dart';
import 'package:flutter_body/models/joint_rotation.dart';
import 'package:flutter_body/models/joint_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime.utc(2026, 9, 2, 8);

  CustomRehabExercise exercise({
    double duration = 2,
    List<ExerciseKeyframe>? keyframes,
  }) {
    return CustomRehabExercise(
      id: 'custom_001',
      name: '右肩抬舉訓練',
      description: '慢慢將右手抬高，再放回原位',
      createdByTherapistId: 'therapist_001',
      createdAt: createdAt,
      updatedAt: createdAt,
      repetitions: 10,
      sets: 3,
      holdSeconds: 5,
      restSeconds: 30,
      duration: duration,
      keyframes: keyframes ??
          [
            ExerciseKeyframe(
              id: 'kf_001',
              time: 0,
              jointRotations: {JointType.rightShoulder: JointRotation.zero},
            ),
            ExerciseKeyframe(
              id: 'kf_002',
              time: 2,
              jointRotations: const {
                JointType.rightShoulder: JointRotation(z: 90),
              },
            ),
          ],
      evaluationRules: const [
        EvaluationRule(
          joint: JointType.rightShoulder,
          axis: RotationAxis.z,
          targetAngle: 90,
          tolerance: 15,
        ),
      ],
    );
  }

  test('CustomRehabExercise JSON roundtrip 保留完整資料', () {
    final original = exercise();
    final decoded = CustomRehabExercise.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
    );

    expect(decoded.toJson(), original.toJson());
    expect(
        decoded.keyframes
            .singleWhere((item) => item.time == 2)
            .jointRotations[JointType.rightShoulder],
        const JointRotation(z: 90));
  });

  test('12 關節多 Keyframes JSON roundtrip 保留 double、enum 與 Map key', () {
    Map<JointType, JointRotation> pose(double offset) {
      return {
        for (var index = 0; index < JointType.values.length; index++)
          JointType.values[index]: JointRotation(
            x: offset + index + 0.25,
            y: -offset - index - 0.5,
            z: offset * 2 + index + 0.75,
          ),
      };
    }

    final original = exercise(
      duration: 2.0,
      keyframes: [
        ExerciseKeyframe(
          id: 'kf_001',
          time: 0.0,
          jointRotations: pose(0),
        ),
        ExerciseKeyframe(
          id: 'kf_002',
          time: 1.0,
          jointRotations: pose(10),
        ),
        ExerciseKeyframe(
          id: 'kf_003',
          time: 2.0,
          jointRotations: pose(20),
        ),
      ],
    );

    final encoded = jsonEncode(original.toJson());
    final decoded = CustomRehabExercise.fromJson(
      jsonDecode(encoded) as Map<String, dynamic>,
    );

    expect(decoded.toJson(), original.toJson());
    expect(decoded.keyframes, hasLength(3));
    for (final keyframe in decoded.keyframes) {
      expect(keyframe.jointRotations.keys.toSet(), JointType.values.toSet());
      expect(keyframe.jointRotations, hasLength(12));
      expect(keyframe.time, isA<double>());
      expect(
        keyframe.jointRotations.values
            .expand((rotation) => [rotation.x, rotation.y, rotation.z]),
        everyElement(isA<double>()),
      );
    }
  });

  test('EvaluationRule 依允許誤差判斷 pass/fail', () {
    const rule = EvaluationRule(
      joint: JointType.rightShoulder,
      axis: RotationAxis.z,
      targetAngle: 90,
      tolerance: 15,
    );

    expect(rule.passes(82), isTrue);
    expect(rule.passes(75), isTrue);
    expect(rule.passes(55), isFalse);
    expect(rule.passes(double.nan), isFalse);
  });

  test('Keyframe 依時間排序', () {
    final result = exercise(keyframes: [
      ExerciseKeyframe(id: 'later', time: 2, jointRotations: const {}),
      ExerciseKeyframe(id: 'first', time: 0, jointRotations: const {}),
      ExerciseKeyframe(id: 'middle', time: 1, jointRotations: const {}),
    ]);

    expect(result.keyframes.map((item) => item.id),
        orderedEquals(['first', 'middle', 'later']));
  });

  test('拒絕超過 duration 的 Keyframe', () {
    expect(
      () => exercise(
        duration: 1,
        keyframes: [
          ExerciseKeyframe(id: 'late', time: 2, jointRotations: const {}),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('拒絕重複 Keyframe time', () {
    expect(
      () => exercise(keyframes: [
        ExerciseKeyframe(id: 'a', time: 1, jointRotations: const {}),
        ExerciseKeyframe(id: 'b', time: 1, jointRotations: const {}),
      ]),
      throwsArgumentError,
    );
  });

  test('fromJson 拒絕 duration = NaN 與負 tolerance', () {
    final json = exercise().toJson();
    json['duration'] = double.nan;
    expect(() => CustomRehabExercise.fromJson(json), throwsFormatException);

    final ruleJson = exercise().evaluationRules.first.toJson();
    ruleJson['tolerance'] = -1;
    expect(() => EvaluationRule.fromJson(ruleJson), throwsFormatException);
  });
}
