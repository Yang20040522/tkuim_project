import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_body/features/analysis/body/body_motion_template.dart';
import 'package:flutter_body/features/analysis/hand/hand_motion_template.dart';
import 'package:flutter_body/features/analysis/hand/hand_normalization.dart';
import 'package:flutter_body/features/analysis/models/environment_metadata.dart';
import 'package:flutter_body/features/analysis/models/motion_action_registry.dart';
import 'package:flutter_body/features/analysis/models/motion_template_catalog.dart';
import 'package:flutter_body/features/analysis/models/template_quality.dart';
import 'package:flutter_body/models/training_action.dart';

void main() {
  test('same action keeps multiple templates in deterministic order', () {
    final older = _bodyTemplate(
      templateId: 'older',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final newerB = _bodyTemplate(
      templateId: 'b',
      createdAt: DateTime.utc(2026, 2, 1),
    );
    final newerA = _bodyTemplate(
      templateId: 'a',
      createdAt: DateTime.utc(2026, 2, 1),
    );

    final entries = MotionTemplateCatalog.fromJsonTemplates([
      older.toJson(),
      newerA.toJson(),
      newerB.toJson(),
    ]);

    expect(entries.map((item) => item.templateId), ['b', 'a', 'older']);
  });

  test('management JSON uses the same deterministic ordering', () {
    final sorted = MotionTemplateCatalog.sortRawTemplates([
      _bodyTemplate(
        templateId: 'older',
        createdAt: DateTime.utc(2026, 1, 1),
      ).toJson(),
      _bodyTemplate(
        templateId: 'a',
        createdAt: DateTime.utc(2026, 2, 1),
      ).toJson(),
      _bodyTemplate(
        templateId: 'b',
        createdAt: DateTime.utc(2026, 2, 1),
      ).toJson(),
    ]);

    expect(sorted.map((item) => item['templateId']), ['b', 'a', 'older']);
  });

  test('action, side and camera compatibility never mix templates', () {
    final standingRight = _bodyTemplate(
      templateId: 'standing-right',
      movementSide: BodySide.right,
    );
    final standingLeft = _bodyTemplate(
      templateId: 'standing-left',
      movementSide: BodySide.left,
    );
    final sideCamera = _bodyTemplate(
      templateId: 'side-camera',
      movementSide: BodySide.right,
      cameraView: CameraView.side,
    );
    final sitToStand = _bodyTemplate(
      templateId: 'sit',
      actionId: 'sit_to_stand',
      actionType: 'sit_to_stand',
    );
    final entries = MotionTemplateCatalog.fromJsonTemplates([
      standingRight.toJson(),
      standingLeft.toJson(),
      sideCamera.toJson(),
      sitToStand.toJson(),
    ]);

    final compatible = MotionTemplateCatalog.filterCompatible(
      entries: entries,
      actionType: ActionType.wipeBody,
      movementSide: BodySide.right,
      cameraView: CameraView.front,
    );

    expect(compatible.map((item) => item.templateId), ['standing-right']);
  });

  test('Body and Hand templates remain typed and cannot cross-match', () {
    final entries = MotionTemplateCatalog.fromJsonTemplates([
      _bodyTemplate(templateId: 'body').toJson(),
      _handTemplate().toJson(),
    ]);

    final body = MotionTemplateCatalog.filterCompatible(
      entries: entries,
      actionType: ActionType.wipeBody,
    );
    final hand = MotionTemplateCatalog.filterCompatible(
      entries: entries,
      actionType: ActionType.turnPalm,
    );

    expect(body.single.modelType, MotionTemplateModelType.body);
    expect(body.single.handTemplate, isNull);
    expect(hand.single.modelType, MotionTemplateModelType.hand);
    expect(hand.single.bodyTemplate, isNull);
  });

  test('old Phase 1 and Phase 2 JSON aliases still load', () {
    final phase1 = _bodyTemplate(
      templateId: 'phase1',
      actionId: null,
      actionType: '站姿抬腳',
    ).toJson();
    final phase2 = _bodyTemplate(
      templateId: 'phase2',
      actionId: null,
      actionType: 'wipeBody',
    ).toJson();

    final entries = MotionTemplateCatalog.fromJsonTemplates([phase1, phase2]);

    expect(entries, hasLength(2));
    expect(entries.every((item) => item.actionId == 'standing_knee_raise'),
        isTrue);
  });
}

BodyMotionTemplate _bodyTemplate({
  required String templateId,
  String? actionId = 'standing_knee_raise',
  String actionType = 'standing_knee_raise',
  DateTime? createdAt,
  BodySide movementSide = BodySide.right,
  CameraView cameraView = CameraView.front,
}) =>
    BodyMotionTemplate(
      schemaVersion: 1,
      templateId: templateId,
      templateName: templateId,
      actionType: actionType,
      actionId: actionId,
      createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
      environment: EnvironmentMetadata(
        movementSide: movementSide,
        cameraView: cameraView,
      ),
      selectedStartMs: 0,
      selectedEndMs: 100,
      qualitySummary: _quality,
      normalizedTrajectory: [
        _bodyPoint(0),
        _bodyPoint(1),
      ],
      featureTrajectory: const [],
      existingSummary: const {},
    );

BodyTrajectoryPoint _bodyPoint(double progress) => BodyTrajectoryPoint(
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

HandMotionTemplate _handTemplate() => HandMotionTemplate(
      schemaVersion: 1,
      templateId: 'hand',
      templateName: 'hand',
      actionType: 'turn_palm',
      actionId: 'turn_palm',
      createdAt: DateTime.utc(2026, 1, 1),
      environment: const EnvironmentMetadata(movementSide: BodySide.right),
      selectedStartMs: 0,
      selectedEndMs: 100,
      qualitySummary: _quality,
      normalizedTrajectory: [
        _handPoint(0),
        _handPoint(1),
      ],
      pinchDistanceSeries: const [0, 1],
      wristOrientation2dSeries: const [0, 1],
      actionIntensitySeries: const [0, 1],
      existingSummary: const {},
    );

HandTrajectoryPoint _handPoint(double progress) => HandTrajectoryPoint(
      progress: progress,
      timestampMs: (progress * 100).round(),
      landmarks: List.generate(
        21,
        (index) => NormalizedHandLandmark(index / 20, progress, 0),
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
