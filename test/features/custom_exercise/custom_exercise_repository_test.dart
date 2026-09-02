import 'dart:convert';

import 'package:flutter_body/features/custom_exercise/repositories/local_custom_exercise_repository.dart';
import 'package:flutter_body/models/custom_rehab_exercise.dart';
import 'package:flutter_body/models/exercise_keyframe.dart';
import 'package:flutter_body/models/joint_rotation.dart';
import 'package:flutter_body/models/joint_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalCustomExerciseRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = LocalCustomExerciseRepository();
  });

  test('repository save 後可依 ID 與清單讀回完整 JSON', () async {
    final original = _exercise();

    await repository.saveExercise(original);

    final loaded = await repository.getExercise(original.id);
    final all = await repository.getAllExercises();
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(LocalCustomExerciseRepository.storageKey);

    expect(loaded?.toJson(), original.toJson());
    expect(all, hasLength(1));
    expect(jsonDecode(raw!), [original.toJson()]);
  });

  test('repository update 依相同 ID upsert，不產生 duplicate', () async {
    final original = _exercise();
    final updated = original.copyWith(
      name: '更新後肩部訓練',
      description: '更新內容',
      updatedAt: DateTime.utc(2026, 9, 3, 9),
    );

    await repository.saveExercise(original);
    await repository.updateExercise(updated);

    final all = await repository.getAllExercises();
    expect(all, hasLength(1));
    expect(all.single.id, original.id);
    expect(all.single.name, '更新後肩部訓練');
    expect(all.single.updatedAt, updated.updatedAt);
  });

  test('repository delete 移除指定 Exercise', () async {
    final first = _exercise();
    final second = _exercise(id: 'custom_002', name: '踝部訓練');
    await repository.saveExercise(first);
    await repository.saveExercise(second);

    await repository.deleteExercise(first.id);

    expect(await repository.getExercise(first.id), isNull);
    expect(
      (await repository.getAllExercises()).map((item) => item.id),
      [second.id],
    );
  });
}

CustomRehabExercise _exercise({
  String id = 'custom_001',
  String name = '肩部訓練',
}) {
  Map<JointType, JointRotation> pose(double offset) => {
        for (var index = 0; index < JointType.values.length; index++)
          JointType.values[index]: JointRotation(
            x: offset + index.toDouble(),
            y: offset - index.toDouble(),
            z: offset + index / 2,
          ),
      };

  return CustomRehabExercise(
    id: id,
    name: name,
    description: '完整 12 關節測試',
    createdByTherapistId: 'therapist_001',
    createdAt: DateTime.utc(2026, 9, 2, 8),
    updatedAt: DateTime.utc(2026, 9, 2, 9),
    repetitions: 10,
    sets: 3,
    holdSeconds: 5,
    restSeconds: 30,
    duration: 1,
    keyframes: [
      ExerciseKeyframe(
        id: 'kf_001',
        time: 0,
        jointRotations: pose(0),
      ),
      ExerciseKeyframe(
        id: 'kf_002',
        time: 1,
        jointRotations: pose(20),
      ),
    ],
    evaluationRules: const [],
  );
}
