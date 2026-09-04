import 'package:flutter/material.dart';
import 'package:flutter_body/features/custom_exercise/custom_exercise_editor_page.dart';
import 'package:flutter_body/features/custom_exercise/custom_exercise_list_page.dart';
import 'package:flutter_body/features/custom_exercise/repositories/custom_exercise_repository.dart';
import 'package:flutter_body/features/custom_exercise/services/custom_exercise_api_client.dart';
import 'package:flutter_body/models/custom_rehab_exercise.dart';
import 'package:flutter_body/models/exercise_keyframe.dart';
import 'package:flutter_body/models/joint_rotation.dart';
import 'package:flutter_body/models/joint_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Editor 載入既有 Exercise 後還原基本資料、Timeline 與姿勢', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _MemoryCustomExerciseRepository();
    final exercise = _exercise();

    await tester.pumpWidget(
      MaterialApp(
        home: CustomExerciseEditorPage(
          initialExercise: exercise,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('custom-exercise-name')))
          .controller
          ?.text,
      exercise.name,
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('custom-exercise-description')),
          )
          .controller
          ?.text,
      exercise.description,
    );
    expect(find.text('K1'), findsOneWidget);
    expect(find.text('K2'), findsOneWidget);
    expect(find.text('0.0 / 1.0 秒'), findsOneWidget);
    expect(find.byKey(const Key('rightShoulder-x-value')), findsOneWidget);
    expect(find.text('5°'), findsOneWidget);

    final secondKeyframe = find.byKey(const Key('keyframe-kf_002'));
    await tester.ensureVisible(secondKeyframe);
    await tester.tap(secondKeyframe);
    await tester.pump();

    expect(find.text('37°'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('play-keyframes')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Editor 驗證名稱與 Keyframes，儲存後以同 ID 更新', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _MemoryCustomExerciseRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: CustomExerciseEditorPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save-custom-exercise')));
    await tester.pump();
    expect(find.text('請輸入動作名稱'), findsOneWidget);
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .clearSnackBars();
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('custom-exercise-name')),
      '右肩活動',
    );
    final addKeyframe = find.byKey(const Key('add-keyframe'));
    await tester.ensureVisible(addKeyframe);
    await tester.tap(addKeyframe);
    await tester.tap(addKeyframe);
    await tester.pump();

    final saveButton = find.byKey(const Key('save-custom-exercise'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.items, hasLength(1));
    expect(repository.items.single.name, '右肩活動');
    expect(repository.items.single.keyframes, hasLength(2));
    expect(find.text('自訂動作已儲存'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('custom-exercise-name')),
      '右肩活動更新',
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.items, hasLength(1));
    expect(repository.items.single.name, '右肩活動更新');
  });

  testWidgets('已儲存清單可開啟與刪除 Exercise', (tester) async {
    final repository = _MemoryCustomExerciseRepository()..seed(_exercise());

    await tester.pumpWidget(
      MaterialApp(
        home: CustomExerciseListPage(
          repository: repository,
          editorBuilder: (exercise, repository) => CustomExerciseEditorPage(
            initialExercise: exercise,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('肩部復健'), findsOneWidget);
    expect(find.text('1.0 秒'), findsOneWidget);
    expect(find.text('2 Keyframes'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('open-saved-exercise-custom_persisted')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CustomExerciseEditorPage), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('custom-exercise-name')))
          .controller
          ?.text,
      '肩部復健',
    );

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('delete-saved-exercise-custom_persisted')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('confirm-delete-custom-exercise')),
    );
    await tester.pumpAndSettle();

    expect(repository.items, isEmpty);
    expect(find.text('尚未儲存自訂動作'), findsOneWidget);
  });

  testWidgets('缺少 token 時已儲存清單顯示開發中不可用並可開啟 Editor',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomExerciseListPage(
          repository: _UnavailableCustomExerciseRepository(),
          editorBuilder: (exercise, repository) => const Scaffold(
            body: Text('Editor opened'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('雲端已儲存自訂動作暫時無法使用'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, '建立動作'));
    await tester.pumpAndSettle();

    expect(find.text('Editor opened'), findsOneWidget);
  });
}

class _UnavailableCustomExerciseRepository
    implements CustomExerciseRepository {
  static const _error = CustomExerciseApiException(
    '開發模式：新版伺服器尚未部署，雲端已儲存自訂動作暫時無法使用。',
    isDevelopmentUnavailable: true,
  );

  @override
  Future<void> deleteExercise(String id) => Future.error(_error);

  @override
  Future<List<CustomRehabExercise>> getAllExercises() => Future.error(_error);

  @override
  Future<CustomRehabExercise?> getExercise(String id) => Future.error(_error);

  @override
  Future<void> saveExercise(CustomRehabExercise exercise) =>
      Future.error(_error);

  @override
  Future<void> updateExercise(CustomRehabExercise exercise) =>
      Future.error(_error);
}

class _MemoryCustomExerciseRepository implements CustomExerciseRepository {
  final Map<String, CustomRehabExercise> _items = {};

  List<CustomRehabExercise> get items => _items.values.toList();

  void seed(CustomRehabExercise exercise) => _items[exercise.id] = exercise;

  @override
  Future<void> saveExercise(CustomRehabExercise exercise) async {
    _items[exercise.id] = exercise;
  }

  @override
  Future<CustomRehabExercise?> getExercise(String id) async => _items[id];

  @override
  Future<List<CustomRehabExercise>> getAllExercises() async =>
      _items.values.toList();

  @override
  Future<void> updateExercise(CustomRehabExercise exercise) =>
      saveExercise(exercise);

  @override
  Future<void> deleteExercise(String id) async {
    _items.remove(id);
  }
}

CustomRehabExercise _exercise() {
  Map<JointType, JointRotation> pose(double rightShoulderX) => {
        for (final joint in JointType.values) joint: JointRotation.zero,
        JointType.rightShoulder: JointRotation(x: rightShoulderX),
      };

  return CustomRehabExercise(
    id: 'custom_persisted',
    name: '肩部復健',
    description: '每日緩慢完成',
    createdByTherapistId: 'therapist_001',
    createdAt: DateTime.utc(2026, 9, 1, 8),
    updatedAt: DateTime.utc(2026, 9, 2, 9, 30),
    repetitions: 10,
    sets: 3,
    holdSeconds: 5,
    restSeconds: 30,
    duration: 1,
    keyframes: [
      ExerciseKeyframe(
        id: 'kf_001',
        time: 0,
        jointRotations: pose(5),
      ),
      ExerciseKeyframe(
        id: 'kf_002',
        time: 1,
        jointRotations: pose(37),
      ),
    ],
    evaluationRules: const [],
  );
}
