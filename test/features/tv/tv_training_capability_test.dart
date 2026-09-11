import 'package:flutter/material.dart';
import 'package:flutter_body/core/platform/app_platform.dart';
import 'package:flutter_body/core/platform/tv_training_capabilities.dart';
import 'package:flutter_body/core/ui/tv_ui.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/plan/plan_repository.dart';
import 'package:flutter_body/features/plan/plan_screen.dart';
import 'package:flutter_body/features/plan/rehab_plan.dart';
import 'package:flutter_body/features/training/action_list_screen.dart';
import 'package:flutter_body/models/training_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppPlatform.current = const AppCapabilities.tv();
    AppSession.userId = 'tv-patient';
  });

  tearDown(() {
    AppPlatform.current = const AppCapabilities.mobile();
    AppSession.userId = null;
  });

  test('TV capability excludes only the four hand actions', () {
    expect(isTvSupportedTrainingAction(ActionType.turnPalm), isFalse);
    expect(isTvSupportedTrainingAction(ActionType.sidePinch), isFalse);
    expect(isTvSupportedTrainingAction(ActionType.wristExtension), isFalse);
    expect(isTvSupportedTrainingAction(ActionType.wristSideBend), isFalse);
    expect(isTvSupportedTrainingAction(ActionType.drawCircle), isTrue);
    expect(isTvSupportedTrainingAction(ActionType.reach), isTrue);

    // The shared mobile catalog remains intact.
    for (final type in kTvUnsupportedActionTypes) {
      expect(kTrainingActions.any((action) => action.type == type), isTrue);
    }
  });

  testWidgets('TV free training hides hand actions and keeps body actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: tvTheme(), home: const ActionListScreen()),
    );
    await tester.pumpAndSettle();

    for (final name in ['翻掌訓練', '側捏訓練', '翹手腕式', '左右彎手腕式']) {
      expect(find.text(name), findsNothing);
    }
    expect(find.text('畫圓訓練'), findsOneWidget);
    expect(find.text('伸手舉高訓練'), findsOneWidget);
    expect(find.text('雙手抬舉式'), findsOneWidget);
  });

  testWidgets('TV plan filters unsupported actions without completing them',
      (tester) async {
    final repository = InMemoryPlanRepository();
    final today = DateTime.now();
    await repository.savePlan(
      RehabPlan(
        patientId: 'tv-patient',
        planId: 'tv-plan',
        createdBy: 'therapist',
        date: today,
        condition: PatientCondition.fracture,
        items: [
          PlanItem(exerciseId: 'ex01', order: 0),
          PlanItem(exerciseId: 'ex02', order: 1),
          PlanItem(exerciseId: 'ex03', order: 2),
          PlanItem(exerciseId: 'ex04', order: 3),
          PlanItem(exerciseId: 'ex05', order: 4),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(theme: tvTheme(), home: PlanScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    for (final name in ['翻掌訓練', '側捏訓練', '翹手腕式', '左右彎手腕式']) {
      expect(find.text(name), findsNothing);
    }
    expect(find.text('畫圓訓練'), findsOneWidget);

    final stored = await repository.getPlanByDate(
      patientId: 'tv-patient',
      date: today,
    );
    expect(stored!.items.every((item) => !item.done), isTrue);
  });

  testWidgets('TV plan shows a clear state when all actions are unsupported',
      (tester) async {
    final repository = InMemoryPlanRepository();
    final today = DateTime.now();
    await repository.savePlan(
      RehabPlan(
        patientId: 'tv-patient',
        planId: 'unsupported-plan',
        createdBy: 'therapist',
        date: today,
        condition: PatientCondition.fracture,
        items: [
          PlanItem(exerciseId: 'ex01', order: 0),
          PlanItem(exerciseId: 'ex02', order: 1),
          PlanItem(exerciseId: 'ex03', order: 2),
          PlanItem(exerciseId: 'ex04', order: 3),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(theme: tvTheme(), home: PlanScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('今天的復健計畫沒有可在電視上執行的動作'),
      findsOneWidget,
    );
  });
}
