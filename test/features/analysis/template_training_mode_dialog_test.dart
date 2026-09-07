import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_body/actions/standing_knee_raise_action.dart';
import 'package:flutter_body/features/analysis/body/body_motion_template.dart';
import 'package:flutter_body/features/analysis/models/environment_metadata.dart';
import 'package:flutter_body/features/analysis/models/motion_action_registry.dart';
import 'package:flutter_body/features/analysis/models/motion_template_catalog.dart';
import 'package:flutter_body/features/analysis/models/template_quality.dart';
import 'package:flutter_body/features/analysis/widgets/template_training_mode_dialog.dart';
import 'package:flutter_body/features/rehab/body_training_screen.dart';
import 'package:flutter_body/models/training_action.dart';

void main() {
  test('AI mode visibility requires both templates and analyzer support', () {
    final standing = MotionActionRegistry.forActionType(ActionType.wipeBody);
    final drawCircle =
        MotionActionRegistry.forActionType(ActionType.drawCircle);
    final template = _entry('template-a');

    expect(
      TemplateTrainingAvailability.evaluate(
        capability: standing,
        templates: const [],
      ).showAiMode,
      isFalse,
    );
    expect(
      TemplateTrainingAvailability.evaluate(
        capability: drawCircle,
        templates: [_entry('draw-template', actionId: 'draw_circle')],
      ).showAiMode,
      isFalse,
    );
    expect(
      TemplateTrainingAvailability.evaluate(
        capability: standing,
        templates: [template],
      ).showAiMode,
      isTrue,
    );
  });

  testWidgets('one template is preselected but AI is not auto-enabled',
      (tester) async {
    final template = _entry('only-template');
    TemplateTrainingSelection? result;
    await tester.pumpWidget(_dialogHarness(
      templates: [template],
      onResult: (value) => result = value,
    ));

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('template-selector')), findsNothing);

    await tester.tap(find.byKey(const Key('template-mode-confirm')));
    await tester.pumpAndSettle();
    expect(result?.aiEnabled, isFalse);

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('template-mode-ai')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('template-selector')), findsOneWidget);
    await tester.tap(find.byKey(const Key('template-mode-confirm')));
    await tester.pumpAndSettle();

    expect(result?.aiEnabled, isTrue);
    expect(result?.selectedTemplate?.templateId, 'only-template');
  });

  testWidgets('multiple templates can be switched and passed into training',
      (tester) async {
    final newest = _entry('newest', createdAt: DateTime.utc(2026, 2, 1));
    final older = _entry('older', createdAt: DateTime.utc(2026, 1, 1));
    TemplateTrainingSelection? result;
    await tester.pumpWidget(_dialogHarness(
      templates: [newest, older],
      onResult: (value) => result = value,
    ));

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('template-mode-ai')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('template-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('older').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('template-mode-confirm')));
    await tester.pumpAndSettle();

    expect(result?.selectedTemplate?.templateId, 'older');
    final action =
        kTrainingActions.firstWhere((item) => item.type == ActionType.wipeBody);
    final screen = BodyTrainingScreen(
      action: StandingKneeRaiseAction(),
      trainingActionMeta: action,
      difficultyMeta: action.difficulties.first,
      selectedTemplate: result!.selectedBodyTemplate,
    );
    expect(screen.selectedTemplate?.templateId, 'older');
  });

  test('general selection never exposes a selected template', () {
    const selection = TemplateTrainingSelection.general();
    expect(selection.aiEnabled, isFalse);
    expect(selection.selectedTemplate, isNull);
    expect(selection.selectedBodyTemplate, isNull);
  });
}

Widget _dialogHarness({
  required List<MotionTemplateCatalogEntry> templates,
  required ValueChanged<TemplateTrainingSelection?> onResult,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final result = await showDialog<TemplateTrainingSelection>(
                context: context,
                builder: (_) => TemplateTrainingModeDialog(
                  actionName: '站姿抬腳式',
                  templates: templates,
                ),
              );
              onResult(result);
            },
            child: const Text('開啟'),
          ),
        ),
      ),
    );

MotionTemplateCatalogEntry _entry(
  String id, {
  DateTime? createdAt,
  String actionId = 'standing_knee_raise',
}) =>
    MotionTemplateCatalogEntry.body(
      actionId: actionId,
      template: BodyMotionTemplate(
        schemaVersion: 1,
        templateId: id,
        templateName: id,
        actionType: actionId,
        actionId: actionId,
        createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
        environment: const EnvironmentMetadata(
          movementSide: BodySide.right,
        ),
        selectedStartMs: 0,
        selectedEndMs: 100,
        qualitySummary: _quality,
        normalizedTrajectory: [
          _point(0),
          _point(1),
        ],
        featureTrajectory: const [],
        existingSummary: const {},
      ),
    );

BodyTrajectoryPoint _point(double progress) => BodyTrajectoryPoint(
      progress: progress,
      timestampMs: (progress * 100).round(),
      landmarks: List.generate(
        17,
        (index) => BodyTemplateLandmark(
          x: index / 20,
          y: progress,
          confidence: 0.9,
        ),
      ),
    );

const _quality = TemplateQualitySummary(
  attemptedFrameCount: 2,
  validFrameCount: 2,
  normalizedFrameCount: 2,
  validRatio: 1,
  normalizationRatio: 1,
  averageConfidence: 1,
  movementIntensity: 1,
  detectedRepetitions: 1,
  issues: [],
);
