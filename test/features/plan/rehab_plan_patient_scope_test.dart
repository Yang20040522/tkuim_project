import 'package:flutter/material.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/account/repositories/therapist_patient_repository.dart';
import 'package:flutter_body/features/account/therapist_home_screen.dart';
import 'package:flutter_body/features/plan/plan_builder_screen.dart';
import 'package:flutter_body/features/plan/plan_repository.dart';
import 'package:flutter_body/features/plan/plan_screen.dart';
import 'package:flutter_body/features/plan/rehab_plan.dart';
import 'package:flutter_body/features/plan/therapist_plan_management_page.dart';
import 'package:flutter_body/models/therapist_patient.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppSession.userId = null;
  });

  tearDown(() {
    AppSession.userId = null;
  });

  group('PlanRepository patient scope', () {
    test('keeps two patients plans isolated on the same date', () async {
      final repository = InMemoryPlanRepository();
      final date = DateTime(2026, 9, 5);
      await repository.savePlan(
        _plan(patientId: 'patientA', date: date, exerciseId: 'ex01'),
      );
      await repository.savePlan(
        _plan(patientId: 'patientB', date: date, exerciseId: 'ex02'),
      );

      final patientA = await repository.getPlanByDate(
        patientId: 'patientA',
        date: date,
      );
      final patientB = await repository.getPlanByDate(
        patientId: 'patientB',
        date: date,
      );

      expect(patientA!.items.single.exerciseId, 'ex01');
      expect(patientB!.items.single.exerciseId, 'ex02');
      expect(patientA.planId, isNot(patientB.planId));
    });

    test('completion updates only the requested patient plan', () async {
      final repository = InMemoryPlanRepository();
      final today = DateTime.now();
      await repository.savePlan(
        _plan(patientId: 'patientA', date: today, exerciseId: 'ex01'),
      );
      await repository.savePlan(
        _plan(patientId: 'patientB', date: today, exerciseId: 'ex01'),
      );

      await markPlanItemDoneByActionName(
        patientId: 'patientA',
        actionName: '翻掌訓練',
        repository: repository,
      );

      final patientA = await repository.getPlanByDate(
        patientId: 'patientA',
        date: today,
      );
      final patientB = await repository.getPlanByDate(
        patientId: 'patientB',
        date: today,
      );
      expect(patientA!.items.single.done, isTrue);
      expect(patientB!.items.single.done, isFalse);
    });

    test('fracture template and generated id retain patient scope', () {
      final repository = InMemoryPlanRepository();
      final date = DateTime(2026, 9, 5);
      final planId = buildPlanId(patientId: '15', date: date);

      final template = repository.buildFractureTemplate('15', planId, date);

      expect(planId, 'plan_15_20260905');
      expect(template.patientId, '15');
      expect(template.toJson()['patientId'], '15');
      expect(RehabPlan.fromJson(template.toJson()).patientId, '15');
    });
  });

  group('Patient PlanScreen permissions', () {
    testWidgets('is view-only and explains an unassigned date', (tester) async {
      AppSession.userId = 'patientA';
      await tester.pumpWidget(
        MaterialApp(
          home: PlanScreen(repository: InMemoryPlanRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('治療師尚未安排這一天的復健計畫'),
        findsOneWidget,
      );
      expect(find.text('新增計畫'), findsNothing);
      expect(find.text('套用標準範本'), findsNothing);
      expect(find.text('依病患狀況安排動作'), findsNothing);
      expect(find.text('修改計畫'), findsNothing);
      expect(find.byType(PlanBuilderScreen), findsNothing);
    });

    testWidgets('does not query a plan without a logged-in patient id',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PlanScreen(repository: InMemoryPlanRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('找不到登入患者，請重新登入'), findsOneWidget);
    });
  });

  group('Therapist plan management', () {
    testWidgets('therapist home opens plan management', (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: TherapistHomeScreen()),
      );
      final entry = find.byKey(const Key('open-rehab-plan-management'));
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(find.byType(TherapistPlanManagementPage), findsOneWidget);
    });

    testWidgets('shows the explicit empty-patient state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TherapistPlanManagementPage(
            patientRepository: _FakePatientRepository(const []),
            repository: InMemoryPlanRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('尚無已綁定患者，請先至患者管理完成綁定'),
        findsOneWidget,
      );
    });

    testWidgets('switches patients and dates without mixing plans',
        (tester) async {
      final repository = InMemoryPlanRepository();
      final today = _dateOnly(DateTime.now());
      final nextWeek = today.add(const Duration(days: 7));
      await repository.savePlan(
        _plan(patientId: 'patientA', date: today, exerciseId: 'ex01'),
      );
      await repository.savePlan(
        _plan(patientId: 'patientB', date: today, exerciseId: 'ex02'),
      );
      await repository.savePlan(
        _plan(patientId: 'patientB', date: nextWeek, exerciseId: 'ex03'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TherapistPlanManagementPage(
            patientRepository: _FakePatientRepository(_patients),
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('翻掌訓練'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('therapist-plan-patient-selector')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('李小華').last);
      await tester.pumpAndSettle();
      expect(find.text('側捏訓練'), findsOneWidget);
      expect(find.text('翻掌訓練'), findsNothing);

      await tester.tap(
        find.byKey(const Key('therapist-plan-next-week')),
      );
      await tester.pumpAndSettle();
      expect(find.text('翹手腕式'), findsOneWidget);
      expect(find.text('側捏訓練'), findsNothing);
    });

    testWidgets('creates a stroke plan through the shared builder',
        (tester) async {
      final repository = InMemoryPlanRepository();
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: TherapistPlanManagementPage(
            patientRepository: _FakePatientRepository([_patients.first]),
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('create-rehab-plan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rehab-condition-stroke')));
      await tester.pumpAndSettle();
      expect(find.byType(PlanBuilderScreen), findsOneWidget);
      expect(find.text('為 王小明 安排訓練動作'), findsOneWidget);

      await tester.tap(find.text('翻掌訓練'));
      await tester.pump();
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();

      expect(find.byType(TherapistPlanManagementPage), findsOneWidget);
      expect(find.text('翻掌訓練'), findsOneWidget);
      expect(find.byKey(const Key('edit-rehab-plan')), findsOneWidget);
    });

    testWidgets('existing plans can be opened for editing', (tester) async {
      final repository = InMemoryPlanRepository();
      final today = _dateOnly(DateTime.now());
      await repository.savePlan(
        _plan(patientId: 'patientA', date: today, exerciseId: 'ex01'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TherapistPlanManagementPage(
            patientRepository: _FakePatientRepository([_patients.first]),
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('edit-rehab-plan')));
      await tester.pumpAndSettle();

      expect(find.byType(PlanBuilderScreen), findsOneWidget);
      expect(find.text('為 王小明 安排訓練動作'), findsOneWidget);
    });

    testWidgets('past dates are read-only', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TherapistPlanManagementPage(
            patientRepository: _FakePatientRepository([_patients.first]),
            repository: InMemoryPlanRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('therapist-plan-previous-week')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('過去日期僅供查看，無法建立或修改計畫'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('create-rehab-plan')), findsNothing);
      expect(find.byKey(const Key('edit-rehab-plan')), findsNothing);
    });
  });
}

RehabPlan _plan({
  required String patientId,
  required DateTime date,
  required String exerciseId,
}) {
  return RehabPlan(
    patientId: patientId,
    planId: buildPlanId(patientId: patientId, date: date),
    createdBy: 'therapist',
    date: date,
    condition: PatientCondition.stroke,
    items: [PlanItem(exerciseId: exerciseId, order: 0)],
  );
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

final _patients = [
  const TherapistPatient(
    patientId: 'patientA',
    patientName: '王小明',
    patientEmail: 'a@example.com',
    relationship: 'THERAPIST',
    boundAt: null,
  ),
  const TherapistPatient(
    patientId: 'patientB',
    patientName: '李小華',
    patientEmail: 'b@example.com',
    relationship: 'THERAPIST',
    boundAt: null,
  ),
];

class _FakePatientRepository implements TherapistPatientRepository {
  final List<TherapistPatient> patients;

  _FakePatientRepository(this.patients);

  @override
  Future<List<TherapistPatient>> getPatients() async => patients;

  @override
  Future<TherapistPatient> bindPatient(String bindingCode) =>
      throw UnimplementedError();

  @override
  Future<TherapistPatientPreview> lookupPatient(String bindingCode) =>
      throw UnimplementedError();

  @override
  Future<void> unbindPatient(String patientId) => throw UnimplementedError();
}
