import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_body/core/ui/app_colors.dart';
import 'package:flutter_body/core/ui/app_theme.dart';
import 'package:flutter_body/features/custom_exercise/custom_exercise_editor_page.dart';
import 'package:flutter_body/features/custom_exercise/patient_assigned_exercise_list_page.dart';
import 'package:flutter_body/features/custom_exercise/repositories/unified_exercise_assignment_repository.dart';
import 'package:flutter_body/features/custom_exercise/services/unified_exercise_assignment_api_client.dart';
import 'package:flutter_body/features/custom_exercise/unified_exercise_assignment_page.dart';
import 'package:flutter_body/features/custom_exercise/widgets/custom_exercise_3d_viewer.dart';
import 'package:flutter_body/models/assignable_exercise.dart';
import 'package:flutter_body/models/custom_exercise_assignment.dart';
import 'package:flutter_body/models/custom_rehab_exercise.dart';
import 'package:flutter_body/models/joint_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Unified assignment API', () {
    test('parses DEFAULT and CUSTOM and keeps type-qualified identities',
        () async {
      late http.Request request;
      final client = UnifiedExerciseAssignmentApiClient(
        baseUrl: 'https://example.test',
        userIdProvider: () => '8',
        identityTokenProvider: () => 'signed-token',
        httpClient: MockClient((incoming) async {
          request = incoming;
          return http.Response(
            jsonEncode([
              {
                'id': '1',
                'name': '翻掌訓練',
                'description': '預設',
                'type': 'DEFAULT',
                'assigned': true,
              },
              {
                'id': '1',
                'name': '肩部活動',
                'description': '自訂',
                'type': 'CUSTOM',
                'assigned': false,
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final exercises = await client.getAssignableExercises('15');

      expect(request.url.path, '/api/assignable-exercises');
      expect(request.url.queryParameters, {'patientId': '15'});
      expect(request.headers['X-User-Id'], '8');
      expect(exercises.first.type, AssignableExerciseType.defaultExercise);
      expect(exercises.last.type, AssignableExerciseType.custom);
      expect(exercises.first.identityKey, 'DEFAULT:1');
      expect(exercises.last.identityKey, 'CUSTOM:1');
    });

    test('assign and unassign use the unified type-aware route', () async {
      final requests = <http.Request>[];
      final client = UnifiedExerciseAssignmentApiClient(
        baseUrl: 'https://example.test',
        userIdProvider: () => '8',
        identityTokenProvider: () => 'signed-token',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.method == 'DELETE') return http.Response('', 204);
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'id': '2',
              'name': '站姿抬腳式訓練',
              'description': '',
              'type': 'DEFAULT',
              'assigned': true,
            })),
            200,
          );
        }),
      );
      const exercise = AssignableExercise(
        id: '2',
        name: '站姿抬腳式訓練',
        description: '',
        type: AssignableExerciseType.defaultExercise,
        assigned: false,
      );

      await client.assign(exercise, '15');
      await client.unassign(exercise, '15');

      expect(requests.map((item) => item.method), ['PUT', 'DELETE']);
      expect(
        requests.first.url.path,
        '/api/assignable-exercises/DEFAULT/2/patients/15',
      );
    });

    test('missing identity token prevents a patient request', () async {
      var requestCount = 0;
      final client = UnifiedExerciseAssignmentApiClient(
        baseUrl: 'https://example.test',
        userIdProvider: () => '15',
        identityTokenProvider: () => null,
        httpClient: MockClient((request) async {
          requestCount++;
          return http.Response('[]', 200);
        }),
      );

      await expectLater(
        client.getPatientAssignedExercises(),
        throwsA(isA<Exception>()),
      );
      expect(requestCount, 0);
    });
  });

  group('Unified assignment widgets', () {
    testWidgets(
        'assignment card changes from inactive to readable when enabled',
        (tester) async {
      final repository = _FakeUnifiedRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: UnifiedExerciseAssignmentPage(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      const identity = 'DEFAULT:1';
      Text title() => tester.widget<Text>(
            find.byKey(const Key('assignable-exercise-title-$identity')),
          );
      Text description() => tester.widget<Text>(
            find.byKey(
              const Key('assignable-exercise-description-$identity'),
            ),
          );
      Icon icon() => tester.widget<Icon>(
            find.byKey(const Key('assignable-exercise-icon-$identity')),
          );

      expect(title().style?.color, AppColors.disabledText);
      expect(description().style?.color, AppColors.disabledText);
      expect(icon().color, AppColors.disabledText);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('assignable-exercise-$identity')),
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();

      expect(title().style?.color, AppColors.primaryText);
      expect(description().style?.color, AppColors.secondaryText);
      expect(icon().color, AppColors.secondaryText);
    });

    testWidgets('therapist sees and filters DEFAULT and CUSTOM exercises',
        (tester) async {
      final repository = _FakeUnifiedRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedExerciseAssignmentPage(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('assignable-exercise-DEFAULT:1')),
          findsOneWidget);
      expect(find.byKey(const Key('assignable-exercise-CUSTOM:custom_1')),
          findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('exercise-type-filter')),
          matching: find.text('預設動作'),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('assignable-exercise-DEFAULT:1')),
          findsOneWidget);
      expect(find.byKey(const Key('assignable-exercise-CUSTOM:custom_1')),
          findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('exercise-type-filter')),
          matching: find.text('自訂動作'),
        ),
      );
      await tester.pump();
      expect(
          find.byKey(const Key('assignable-exercise-DEFAULT:1')), findsNothing);
      expect(find.byKey(const Key('assignable-exercise-CUSTOM:custom_1')),
          findsOneWidget);
    });

    testWidgets('therapist can assign and unassign either exercise type',
        (tester) async {
      final repository = _FakeUnifiedRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedExerciseAssignmentPage(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      final defaultSwitch = find.descendant(
        of: find.byKey(const Key('assignable-exercise-DEFAULT:1')),
        matching: find.byType(Switch),
      );
      await tester.tap(defaultSwitch);
      await tester.pumpAndSettle();
      expect(repository.assignedKeys, contains('DEFAULT:1'));

      final customSwitch = find.descendant(
        of: find.byKey(const Key('assignable-exercise-CUSTOM:custom_1')),
        matching: find.byType(Switch),
      );
      await tester.tap(customSwitch);
      await tester.pumpAndSettle();
      expect(repository.unassignedKeys, contains('CUSTOM:custom_1'));
    });

    testWidgets('patient sees both types and routes by exercise type',
        (tester) async {
      final repository = _FakeUnifiedRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: PatientAssignedExerciseListPage(
            repository: repository,
            defaultExerciseBuilder: (exercise) =>
                const Scaffold(body: Text('DEFAULT DESTINATION')),
            customExerciseBuilder: (exercise) =>
                const Scaffold(body: Text('CUSTOM DESTINATION')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('翻掌訓練'), findsOneWidget);
      expect(find.text('肩部活動'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key(
              'patient-assigned-exercise-title-CUSTOM:custom_1',
            )))
            .style
            ?.color,
        AppColors.primaryText,
      );

      await tester.tap(
        find.byKey(const Key('patient-assigned-exercise-DEFAULT:1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('DEFAULT DESTINATION'), findsOneWidget);
      Navigator.of(tester.element(find.text('DEFAULT DESTINATION'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const Key('patient-assigned-exercise-CUSTOM:custom_1'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('CUSTOM DESTINATION'), findsOneWidget);
    });

    testWidgets('unified pages provide empty and network error states',
        (tester) async {
      final emptyRepository = _FakeUnifiedRepository()..patients = const [];
      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedExerciseAssignmentPage(repository: emptyRepository),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('尚無已綁定的患者'), findsOneWidget);

      final errorRepository = _FakeUnifiedRepository()
        ..patientListError = StateError('offline');
      await tester.pumpWidget(
        MaterialApp(
          home: PatientAssignedExerciseListPage(
            repository: errorRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('offline'), findsOneWidget);
      expect(find.text('重試'), findsOneWidget);
    });
  });

  group('Editor floating preview', () {
    testWidgets('uses one viewer and switches by actual viewport visibility',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: CustomExerciseEditorPage()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CustomExercise3dViewer), findsOneWidget);
      expect(
        tester
            .widget<CustomExercise3dViewer>(
              find.byType(CustomExercise3dViewer),
            )
            .compactPreview,
        isFalse,
      );

      final scrollView = tester.widget<SingleChildScrollView>(
        find.byKey(const Key('custom-exercise-editor-scroll-view')),
      );
      scrollView.controller!.jumpTo(700);
      await tester.pumpAndSettle();

      expect(find.byType(CustomExercise3dViewer), findsOneWidget);
      expect(
        tester
            .widget<CustomExercise3dViewer>(
              find.byType(CustomExercise3dViewer),
            )
            .compactPreview,
        isTrue,
      );
      expect(
        find.descendant(
          of: find.byType(CustomExercise3dViewer),
          matching: find.textContaining('主要關節'),
        ),
        findsNothing,
      );

      final ankle = find.byKey(const Key('joint-leftAnkle'));
      await tester.ensureVisible(ankle);
      await tester.tap(ankle);
      await tester.pump();
      expect(
        tester
            .widget<CustomExercise3dViewer>(
              find.byType(CustomExercise3dViewer),
            )
            .selectedJoint,
        JointType.leftAnkle,
      );

      final xSlider = tester.widget<Slider>(
        find.descendant(
          of: find.byKey(const Key('leftAnkle-x-slider')),
          matching: find.byType(Slider),
        ),
      );
      xSlider.onChanged!(30);
      await tester.pump();
      expect(
        tester
            .widget<CustomExercise3dViewer>(
              find.byType(CustomExercise3dViewer),
            )
            .jointRotations[JointType.leftAnkle]
            ?.x,
        30,
      );

      scrollView.controller!.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CustomExercise3dViewer>(
              find.byType(CustomExercise3dViewer),
            )
            .compactPreview,
        isFalse,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

class _FakeUnifiedRepository implements UnifiedExerciseAssignmentRepository {
  List<AssignablePatient> patients = const [
    AssignablePatient(patientId: '15', patientName: '測試患者'),
  ];
  List<AssignableExercise> exercises = const [
    AssignableExercise(
      id: '1',
      name: '翻掌訓練',
      description: '預設動作',
      type: AssignableExerciseType.defaultExercise,
      assigned: false,
    ),
    AssignableExercise(
      id: 'custom_1',
      name: '肩部活動',
      description: '自訂動作',
      type: AssignableExerciseType.custom,
      assigned: true,
    ),
  ];
  Object? patientListError;
  final List<String> assignedKeys = [];
  final List<String> unassignedKeys = [];

  @override
  Future<AssignableExercise> assign(
    AssignableExercise exercise,
    String patientId,
  ) async {
    assignedKeys.add(exercise.identityKey);
    return exercise.copyWith(assigned: true);
  }

  @override
  Future<List<AssignableExercise>> getAssignableExercises(
    String patientId,
  ) async =>
      exercises;

  @override
  Future<List<AssignablePatient>> getAssignablePatients() async => patients;

  @override
  Future<List<AssignableExercise>> getPatientAssignedExercises() async {
    if (patientListError != null) throw patientListError!;
    return exercises.map((item) => item.copyWith(assigned: true)).toList();
  }

  @override
  Future<CustomRehabExercise?> getPatientCustomExercise(
    String exerciseId,
  ) async {
    final now = DateTime.utc(2026, 9, 4);
    return CustomRehabExercise(
      id: exerciseId,
      name: '肩部活動',
      description: '自訂動作',
      createdAt: now,
      updatedAt: now,
      repetitions: 10,
      sets: 3,
      holdSeconds: 0,
      restSeconds: 30,
      duration: 0,
      keyframes: const [],
      evaluationRules: const [],
    );
  }

  @override
  Future<void> unassign(
    AssignableExercise exercise,
    String patientId,
  ) async {
    unassignedKeys.add(exercise.identityKey);
  }
}
