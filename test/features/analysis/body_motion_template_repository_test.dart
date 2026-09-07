import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_body/features/analysis/body/body_motion_template.dart';
import 'package:flutter_body/features/analysis/body/body_motion_template_repository.dart';
import 'package:flutter_body/features/analysis/body/body_template_selector.dart';
import 'package:flutter_body/features/analysis/models/environment_metadata.dart';
import 'package:flutter_body/features/analysis/models/template_quality.dart';
import 'package:flutter_body/features/analysis/storage/local_motion_template_repository.dart';

void main() {
  test('loads existing Phase 1 JSON and matches the canonical action',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('motion_templates_');
    addTearDown(() => directory.delete(recursive: true));
    final storage = LocalMotionTemplateRepository(
      directoryProvider: () async => directory,
    );
    final repository = BodyMotionTemplateRepository(storage: storage);
    final oldPhase1Json = _oldPhase1Template().toJson();
    await File('${directory.path}/template_phase1.json')
        .writeAsString(jsonEncode(oldPhase1Json));

    final loaded = await repository.loadTemplates();
    final selected = BodyTemplateSelector.selectStandingKneeRaise(
      templates: loaded,
      movementSide: BodySide.right,
    );

    expect(loaded, hasLength(1));
    expect(selected, isNotNull);
    expect(selected!.templateId, 'phase1-template');
    expect(selected.actionType, '站姿抬腳');
    expect(BodyTemplateSelector.standingKneeRaiseActionId, 'wipeBody');
    expect(selected.toJson(), oldPhase1Json);
  });

  test('generic storage remains compatible with Body and Hand JSON', () async {
    final directory =
        await Directory.systemTemp.createTemp('motion_templates_');
    addTearDown(() => directory.delete(recursive: true));
    final storage = LocalMotionTemplateRepository(
      directoryProvider: () async => directory,
    );

    final saved = await storage.saveTemplateJson(_oldPhase1Template().toJson());
    final listed = await storage.listTemplateJson();

    expect(await saved.exists(), isTrue);
    expect(listed, hasLength(1));
    expect(listed.single['templateId'], 'phase1-template');
    expect(
      File(listed.single['_filePath'] as String).absolute.uri,
      saved.absolute.uri,
    );
  });
}

BodyMotionTemplate _oldPhase1Template() => BodyMotionTemplate(
      schemaVersion: 1,
      templateId: 'phase1-template',
      templateName: '站姿抬腳 標準模板',
      actionType: '站姿抬腳',
      createdAt: DateTime.utc(2026, 9, 7),
      environment: const EnvironmentMetadata(
        cameraView: CameraView.front,
        supportType: SupportType.chair,
        supportSide: BodySide.left,
        movementSide: BodySide.right,
      ),
      selectedStartMs: 100,
      selectedEndMs: 2100,
      qualitySummary: _quality,
      normalizedTrajectory: List<BodyTrajectoryPoint>.generate(
        21,
        (index) => BodyTrajectoryPoint(
          progress: index / 20,
          timestampMs: 100 + index * 100,
          landmarks: List<BodyTemplateLandmark>.generate(
            17,
            (joint) => BodyTemplateLandmark(
              x: joint / 20,
              y: index / 20,
              confidence: 0.9,
            ),
          ),
        ),
      ),
      featureTrajectory: const [],
      existingSummary: const {
        'estimatedReps': 1,
        'symmetryScore': 0.9,
        'stabilityScore': 0.8,
        'mainJoints': [],
        'actionIntensity': [],
      },
    );

const _quality = TemplateQualitySummary(
  attemptedFrameCount: 21,
  validFrameCount: 21,
  normalizedFrameCount: 21,
  validRatio: 1,
  normalizationRatio: 1,
  averageConfidence: 0.9,
  movementIntensity: 0.1,
  detectedRepetitions: 1,
  issues: [],
);
