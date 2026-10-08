import 'package:flutter/material.dart';
import 'package:flutter_body/core/ui/app_theme.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/account/patient_management_page.dart';
import 'package:flutter_body/features/account/repositories/therapist_patient_repository.dart';
import 'package:flutter_body/features/account/role_select_screen.dart';
import 'package:flutter_body/features/account/therapist_home_screen.dart';
import 'package:flutter_body/features/account/user_role.dart';
import 'package:flutter_body/features/chat/chat_backend.dart';
import 'package:flutter_body/features/chat/chat_models.dart';
import 'package:flutter_body/features/custom_exercise/custom_exercise_editor_page.dart';
import 'package:flutter_body/features/custom_exercise/custom_exercise_list_page.dart';
import 'package:flutter_body/features/custom_exercise/repositories/custom_exercise_repository.dart';
import 'package:flutter_body/features/custom_exercise/unified_exercise_assignment_page.dart';
import 'package:flutter_body/features/plan/therapist_plan_management_page.dart';
import 'package:flutter_body/features/rehab_ml/ml_research_api.dart';
import 'package:flutter_body/models/custom_rehab_exercise.dart';
import 'package:flutter_body/models/therapist_patient.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.role = UserRole.therapist;
    AppSession.userId = 'synthetic-therapist';
    AppSession.name = '測試治療師';
    AppSession.customExerciseToken = null;
  });
  tearDown(() {
    AppSession.role = null;
    AppSession.userId = null;
    AppSession.name = null;
    AppSession.customExerciseToken = null;
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    _Patients? patients,
    _Exercises? exercises,
    MlResearchRemote? research,
    double scale = 1,
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: TherapistHomeScreen(
        chatBackend: _Chat(),
        patientRepository: patients ?? _Patients(),
        exerciseRepository: exercises ?? _Exercises(),
        researchRemote: research,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('dashboard header uses real session name and all five actions',
      (tester) async {
    await pumpHome(tester);
    expect(find.text('您好，'), findsOneWidget);
    expect(find.text('測試治療師'), findsOneWidget);
    expect(find.text('一起幫助患者，讓復健更有效率'), findsOneWidget);
    expect(find.text('照護概覽'), findsOneWidget);
    expect(find.text('快速功能'), findsOneWidget);
    for (final key in _routes.keys) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    expect(find.text('首頁'), findsOneWidget);
    expect(find.byKey(const Key('therapist-tab-chat')), findsOneWidget);
  });

  testWidgets(
      'summary counts use repositories once, not on rebuild or tab change',
      (tester) async {
    final patients = _Patients(count: 2);
    final exercises = _Exercises(count: 3);
    await pumpHome(tester, patients: patients, exercises: exercises);
    expect(
        find.descendant(
            of: find.byKey(const Key('summary-patients')),
            matching: find.text('2')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('summary-exercises')),
            matching: find.text('3')),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('therapist-tab-chat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('therapist-tab-home')));
    await tester.pumpAndSettle();
    expect(patients.calls, 1);
    expect(exercises.calls, 1);
    await tester.drag(
        find.byKey(const Key('therapist-home-list')), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(patients.calls, 2);
    expect(exercises.calls, 2);
  });

  testWidgets(
      'unavailable summary APIs show -- without disabling feature cards',
      (tester) async {
    await pumpHome(tester,
        patients: _Patients(fail: true), exercises: _Exercises(fail: true));
    expect(find.text('--'), findsNWidgets(2));
    expect(find.byKey(const Key('overview-unavailable')), findsOneWidget);
    await tester
        .ensureVisible(find.byKey(const Key('open-patient-management')));
    await tester.tap(find.byKey(const Key('open-patient-management')));
    await tester.pumpAndSettle();
    expect(find.byType(PatientManagementPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('summary failure is independent; zero is a valid count',
      (tester) async {
    await pumpHome(tester, exercises: _Exercises(fail: true));
    expect(
        find.descendant(
            of: find.byKey(const Key('summary-patients')),
            matching: find.text('0')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('summary-exercises')),
            matching: find.text('--')),
        findsOneWidget);
  });

  for (final route in _routes.entries) {
    testWidgets('${route.key} opens original ${route.value} page',
        (tester) async {
      await pumpHome(tester);
      final card = find.byKey(Key(route.key));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(route.value), findsOneWidget);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(route.value))).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('therapist-home-list')), findsOneWidget);
    });
  }

  for (final width in [360.0, 390.0, 412.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
          'dashboard fits ${width}px with text scale $scale and long name',
          (tester) async {
        AppSession.name = '測試專業物理治療師很長的姓名';
        await pumpHome(tester, scale: scale, width: width);
        for (final key in [..._routes.keys, 'open-research-samples']) {
          final finder = find.byKey(Key(key));
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          expect(finder.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets(
      'research management appears only after backend authority resolves',
      (tester) async {
    AppSession.customExerciseToken = 'synthetic-token';
    await pumpHome(tester, research: _Authority(true));
    await tester.scrollUntilVisible(
      find.byKey(const Key('open-research-management')),
      250,
      scrollable: find.descendant(
        of: find.byKey(const Key('therapist-home-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.byKey(const Key('open-research-management')), findsOneWidget);
  });

  testWidgets('ordinary therapist retains annotation entry but not management',
      (tester) async {
    AppSession.customExerciseToken = 'synthetic-token';
    await pumpHome(tester, research: _Authority(false));
    await tester.scrollUntilVisible(
      find.byKey(const Key('open-research-samples')),
      250,
      scrollable: find.descendant(
        of: find.byKey(const Key('therapist-home-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.drag(
        find.byKey(const Key('therapist-home-list')), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-research-samples')), findsOneWidget);
    expect(find.byKey(const Key('open-research-management')), findsNothing);
  });

  testWidgets(
      'logout clears original session and returns to existing login route',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'session_userId': 'synthetic-therapist'});
    await pumpHome(tester);
    await tester.tap(find.text('登出'));
    await tester.pumpAndSettle();
    expect(find.byType(RoleSelectScreen), findsOneWidget);
    expect(AppSession.userId, isNull);
    expect(AppSession.role, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('session_userId'), isNull);
    expect(tester.takeException(), isNull);
  });
}

const _routes = <String, Type>{
  'open-custom-exercise-editor': CustomExerciseEditorPage,
  'open-saved-custom-exercises': CustomExerciseListPage,
  'open-patient-management': PatientManagementPage,
  'open-unified-exercise-assignment': UnifiedExerciseAssignmentPage,
  'open-rehab-plan-management': TherapistPlanManagementPage,
};

class _Patients implements TherapistPatientRepository {
  _Patients({this.count = 0, this.fail = false});
  final int count;
  final bool fail;
  int calls = 0;
  @override
  Future<List<TherapistPatient>> getPatients() async {
    calls++;
    if (fail) throw StateError('synthetic unavailable API');
    return List.generate(
        count,
        (index) => TherapistPatient(
              patientId: 'synthetic-$index',
              patientName: '測試患者',
              patientEmail: 'synthetic@example.invalid',
              relationship: 'THERAPIST',
              boundAt: null,
            ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Exercises implements CustomExerciseRepository {
  _Exercises({this.count = 0, this.fail = false});
  final int count;
  final bool fail;
  int calls = 0;
  @override
  Future<List<CustomRehabExercise>> getAllExercises() async {
    calls++;
    if (fail) throw StateError('synthetic unavailable API');
    final now = DateTime.utc(2026);
    return List.generate(
        count,
        (index) => CustomRehabExercise(
              id: 'synthetic-$index',
              name: '測試動作',
              description: '',
              createdAt: now,
              updatedAt: now,
              repetitions: 1,
              sets: 1,
              holdSeconds: 1,
              restSeconds: 1,
              duration: 5,
              keyframes: [],
              evaluationRules: [],
            ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Chat implements ChatBackend {
  @override
  Future<List<ChatContact>> getContacts() async => [];
  @override
  Stream<List<RemoteConversation>> watchConversations(String myUserId) =>
      const Stream.empty();
  @override
  Stream<List<UnreadCount>> watchUnreadCounts(String myUserId) =>
      const Stream.empty();
  @override
  void dispose() {}
  @override
  void refresh() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Authority extends MlResearchRemote {
  _Authority(this.canManage);
  final bool canManage;
  @override
  Future<Map<String, dynamic>> authority() async => {'canManage': canManage};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
