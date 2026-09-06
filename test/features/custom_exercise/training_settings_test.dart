import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_body/features/custom_exercise/controllers/custom_exercise_editor_controller.dart';
import 'package:flutter_body/features/custom_exercise/controllers/custom_exercise_playback_controller.dart';
import 'package:flutter_body/features/custom_exercise/custom_exercise_editor_page.dart';
import 'package:flutter_body/features/custom_exercise/repositories/custom_exercise_repository.dart';
import 'package:flutter_body/features/pose_measurement/pose_training_page.dart';
import 'package:flutter_body/models/custom_rehab_exercise.dart';
import 'package:flutter_body/models/exercise_keyframe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new CUSTOM settings persist exact values and retime existing poses',
      () {
    final controller = CustomExerciseEditorController(
      now: DateTime.utc(2026, 9, 6),
    );
    addTearDown(controller.dispose);
    controller.updateBasicInfo(name: '肩部訓練', description: '測試');
    controller.addKeyframeFromCurrentPose();
    controller.addKeyframeFromCurrentPose();
    final posesBefore = controller.keyframes
        .map((keyframe) => keyframe.jointRotations)
        .toList(growable: false);

    expect(
      controller.updateTrainingSettings(
        animationDurationSeconds: 6,
        repetitions: 2,
        sets: 3,
        holdSeconds: 1.5,
      ),
      isNull,
    );
    final exercise = controller.createSaveSnapshot();

    expect(exercise.duration, 6);
    expect(exercise.keyframes.last.time, 6);
    expect(exercise.repetitions, 2);
    expect(exercise.sets, 3);
    expect(exercise.holdSeconds, 1.5);
    expect(
      exercise.keyframes.map((keyframe) => keyframe.jointRotations),
      posesBefore,
    );
  });

  test('settings JSON round-trip and legacy duration remain compatible', () {
    final original = _exercise(
      duration: 6,
      repetitions: 2,
      sets: 3,
      holdSeconds: 1.5,
    );
    final json = original.toJson();
    expect(json, isNot(contains('animationDurationSeconds')));

    final decoded = CustomRehabExercise.fromJson(
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
    );
    expect(decoded.duration, 6);
    expect(decoded.repetitions, 2);
    expect(decoded.sets, 3);
    expect(decoded.holdSeconds, 1.5);

    final legacy = _exercise(duration: 4).toJson();
    expect(CustomRehabExercise.fromJson(legacy).duration, 4);
  });

  test('settings validation rejects out-of-range values without clamping', () {
    final controller = CustomExerciseEditorController();
    addTearDown(controller.dispose);

    expect(
      controller.updateTrainingSettings(
        animationDurationSeconds: 0.9,
        repetitions: 10,
        sets: 3,
        holdSeconds: 1.5,
      ),
      '動畫播放時間必須介於 1～60 秒',
    );
    expect(
      controller.updateTrainingSettings(
        animationDurationSeconds: 5,
        repetitions: 101,
        sets: 3,
        holdSeconds: 1.5,
      ),
      '每組次數必須介於 1～100 次',
    );
    expect(
      controller.updateTrainingSettings(
        animationDurationSeconds: 5,
        repetitions: 10,
        sets: 21,
        holdSeconds: 1.5,
      ),
      '組數必須介於 1～20 組',
    );
    expect(
      controller.updateTrainingSettings(
        animationDurationSeconds: 5,
        repetitions: 10,
        sets: 3,
        holdSeconds: 0.4,
      ),
      '保持時間必須介於 0.5～30 秒',
    );
  });

  test('configured values reach playback and training configuration', () {
    final exercise = _exercise(
      duration: 6,
      repetitions: 2,
      sets: 3,
      holdSeconds: 1.5,
    );
    final playback = CustomExercisePlaybackController(exercise: exercise);
    addTearDown(playback.dispose);
    final training = trainingSessionConfigFor(
      customExercise: exercise,
      hasRules: true,
    );

    expect(playback.exercise.duration, 6);
    expect(playback.exercise.keyframes.last.time, 6);
    expect(training.targetReps, 2);
    expect(training.targetSets, 3);
    expect(training.holdDuration, const Duration(milliseconds: 1500));
  });

  testWidgets('Editor edit/save/reopen preserves all four settings',
      (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(MaterialApp(
      home: CustomExerciseEditorPage(
        key: const ValueKey('first-editor'),
        initialExercise: _exercise(duration: 4),
        repository: repository,
      ),
    ));
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 'animation-duration-seconds'), '4');
    expect(_fieldText(tester, 'exercise-repetitions'), '10');
    expect(_fieldText(tester, 'exercise-sets'), '3');
    expect(_fieldText(tester, 'exercise-hold-seconds'), '5');

    await tester.enterText(
      _field('animation-duration-seconds'),
      '6',
    );
    await tester.enterText(_field('exercise-repetitions'), '2');
    await tester.enterText(_field('exercise-sets'), '2');
    await tester.enterText(
      _field('exercise-hold-seconds'),
      '1.5',
    );
    await tester.tap(find.byKey(const Key('save-custom-exercise')));
    await tester.pumpAndSettle();

    final saved = repository.updated.single;
    expect(saved.duration, 6);
    expect(saved.keyframes.last.time, 6);
    expect(saved.repetitions, 2);
    expect(saved.sets, 2);
    expect(saved.holdSeconds, 1.5);

    await tester.pumpWidget(MaterialApp(
      home: CustomExerciseEditorPage(
        key: const ValueKey('reopened-editor'),
        initialExercise: saved,
        repository: repository,
      ),
    ));
    await tester.pumpAndSettle();
    expect(_fieldText(tester, 'animation-duration-seconds'), '6');
    expect(_fieldText(tester, 'exercise-repetitions'), '2');
    expect(_fieldText(tester, 'exercise-sets'), '2');
    expect(_fieldText(tester, 'exercise-hold-seconds'), '1.5');
  });
}

String _fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(_field(key)).controller!.text;

Finder _field(String key) => find.descendant(
      of: find.byKey(Key(key)),
      matching: find.byType(TextField),
    );

CustomRehabExercise _exercise({
  double duration = 5,
  int repetitions = 10,
  int sets = 3,
  double holdSeconds = 5,
}) {
  return CustomRehabExercise(
    id: 'settings-test',
    name: '設定測試',
    description: '',
    createdAt: DateTime.utc(2026, 9, 6),
    updatedAt: DateTime.utc(2026, 9, 6),
    repetitions: repetitions,
    sets: sets,
    holdSeconds: holdSeconds,
    restSeconds: 30,
    duration: duration,
    keyframes: [
      ExerciseKeyframe(id: 'k1', time: 0, jointRotations: const {}),
      ExerciseKeyframe(id: 'k2', time: duration, jointRotations: const {}),
    ],
    evaluationRules: const [],
  );
}

class _Repository implements CustomExerciseRepository {
  final List<CustomRehabExercise> updated = [];

  @override
  Future<void> updateExercise(CustomRehabExercise exercise) async {
    updated.add(exercise);
  }

  @override
  Future<void> saveExercise(CustomRehabExercise exercise) async {}

  @override
  Future<void> deleteExercise(String id) async {}

  @override
  Future<List<CustomRehabExercise>> getAllExercises() async => [];

  @override
  Future<CustomRehabExercise?> getExercise(String id) async => null;
}
