import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_body/actions/standing_knee_raise_action.dart';
import 'package:flutter_body/features/analysis/body/body_motion_template.dart';
import 'package:flutter_body/features/analysis/body/body_rep_trajectory_collector.dart';
import 'package:flutter_body/features/analysis/body/body_template_analyzer.dart';
import 'package:flutter_body/features/analysis/models/environment_metadata.dart';
import 'package:flutter_body/features/analysis/models/template_quality.dart';
import 'package:flutter_body/models/body_frame.dart';
import 'package:flutter_body/models/training_action.dart';

void main() {
  const analyzer = BodyTemplateAnalyzer();

  test('identical and near-identical trajectories receive high scores', () {
    final template = _template();
    final identical = analyzer.analyze(
      template: template,
      patientSamples: _patientSamples(),
      movementSide: BodySide.right,
      currentCameraView: CameraView.front,
    );
    final near = analyzer.analyze(
      template: template,
      patientSamples: _patientSamples(
        deviatedJoint: 14,
        deviation: const Offset(0.025, 0),
      ),
      movementSide: BodySide.right,
      currentCameraView: CameraView.front,
    );

    expect(identical.valid, isTrue);
    expect(identical.overallScore, closeTo(100, 1e-6));
    expect(near.valid, isTrue);
    expect(near.overallScore!, greaterThan(95));
  });

  test('clearly deviated trajectory scores significantly lower', () {
    final template = _template();
    final matching = analyzer.analyze(
      template: template,
      patientSamples: _patientSamples(),
      movementSide: BodySide.right,
      currentCameraView: CameraView.front,
    );
    final deviated = analyzer.analyze(
      template: template,
      patientSamples: _patientSamples(
        deviatedJoints: const [12, 14, 16],
        deviation: const Offset(1.5, 0.8),
      ),
      movementSide: BodySide.right,
      currentCameraView: CameraView.front,
    );

    expect(deviated.valid, isTrue);
    expect(deviated.overallScore!, lessThan(matching.overallScore! - 35));
  });

  test('translation and scale are removed by BodyNormalization', () {
    final template = _template();
    final baseline = analyzer.analyze(
      template: template,
      patientSamples:
          _patientSamples(scale: 0.2, origin: const Offset(0.5, 0.6)),
      movementSide: BodySide.right,
      currentCameraView: CameraView.front,
    );
    final transformed = analyzer.analyze(
      template: template,
      patientSamples:
          _patientSamples(scale: 0.37, origin: const Offset(0.2, 0.35)),
      movementSide: BodySide.right,
      currentCameraView: CameraView.front,
    );

    expect(baseline.valid, isTrue);
    expect(transformed.valid, isTrue);
    expect(
      (baseline.overallScore! - transformed.overallScore!).abs(),
      lessThan(0.001),
    );
  });

  test('insufficient frames produce no score', () {
    final result = analyzer.analyze(
      template: _template(),
      patientSamples: _patientSamples(frameCount: 3),
      movementSide: BodySide.right,
      currentCameraView: CameraView.front,
    );

    expect(result.valid, isFalse);
    expect(result.enoughData, isFalse);
    expect(result.overallScore, isNull);
  });

  test('score is always clamped to 0 through 100', () {
    final result = analyzer.analyze(
      template: _template(),
      patientSamples: _patientSamples(
        deviatedJoints: List<int>.generate(17, (index) => index),
        deviation: const Offset(1000, -1000),
      ),
      movementSide: BodySide.right,
      currentCameraView: CameraView.front,
    );

    expect(result.valid, isTrue);
    expect(result.overallScore, inInclusiveRange(0, 100));
    expect(result.similarity, inInclusiveRange(0, 1));
  });

  test('movement side selects the matching anatomical template', () {
    final left = _template(
      templateId: 'left-template',
      movementSide: BodySide.left,
      trajectorySide: BodySide.left,
      createdAt: DateTime.utc(2026, 9, 8),
    );
    final right = _template(
      templateId: 'right-template',
      movementSide: BodySide.right,
      createdAt: DateTime.utc(2026, 9, 7),
    );

    final result = analyzer.analyzeBestMatching(
      templates: [left, right],
      patientSamples: _patientSamples(),
      currentCameraView: CameraView.front,
    );

    expect(result.valid, isTrue);
    expect(result.movementSide, BodySide.right);
    expect(result.templateId, 'right-template');
  });

  test('supported anatomical arm is downweighted', () {
    final template = _template(
      supportType: SupportType.chair,
      supportSide: BodySide.left,
    );
    final supportedArmDeviation = analyzer.analyze(
      template: template,
      patientSamples: _patientSamples(
        deviatedJoints: const [7, 9],
        deviation: const Offset(1, 0.5),
      ),
      movementSide: BodySide.right,
      currentCameraView: CameraView.front,
    );
    final unsupportedArmDeviation = analyzer.analyze(
      template: template,
      patientSamples: _patientSamples(
        deviatedJoints: const [8, 10],
        deviation: const Offset(1, 0.5),
      ),
      movementSide: BodySide.right,
      currentCameraView: CameraView.front,
    );

    expect(supportedArmDeviation.valid, isTrue);
    expect(unsupportedArmDeviation.valid, isTrue);
    expect(supportedArmDeviation.overallScore!,
        greaterThan(unsupportedArmDeviation.overallScore!));
  });

  test('camera view mismatch returns unavailable instead of a false score', () {
    final result = analyzer.analyze(
      template: _template(cameraView: CameraView.side),
      patientSamples: _patientSamples(),
      movementSide: BodySide.right,
      currentCameraView: CameraView.front,
    );

    expect(result.valid, isFalse);
    expect(result.enoughData, isTrue);
    expect(result.overallScore, isNull);
  });

  test('no template never changes the existing scored rep decision', () {
    final action = StandingKneeRaiseAction()..selectRightLeg();
    final feedback = action.update(const BodyFrame(joints: {
      RehabJoint.leftShoulder: Offset(0.4, 0.2),
      RehabJoint.rightShoulder: Offset(0.6, 0.2),
      RehabJoint.rightHip: Offset(0.55, 0.6),
      RehabJoint.rightKnee: Offset(0.55, 0.4),
      RehabJoint.rightAnkle: Offset(0.55, 0.8),
    }));
    final analysis = analyzer.analyzeBestMatching(
      templates: const [],
      patientSamples: _patientSamples(),
      currentCameraView: CameraView.front,
    );

    expect(feedback.scored, isTrue);
    expect(analysis.valid, isFalse);
    expect(analysis.overallScore, isNull);
    expect(action.successCount, 1);
    expect(ActionType.wipeBody.name, 'wipeBody');
  });
}

BodyMotionTemplate _template({
  String templateId = 'standing-right',
  BodySide movementSide = BodySide.right,
  BodySide trajectorySide = BodySide.right,
  SupportType supportType = SupportType.none,
  BodySide supportSide = BodySide.none,
  CameraView cameraView = CameraView.front,
  DateTime? createdAt,
  String actionType = 'wipeBody',
}) {
  return BodyMotionTemplate(
    schemaVersion: BodyMotionTemplate.currentSchemaVersion,
    templateId: templateId,
    templateName: '站姿抬腳標準',
    actionType: actionType,
    createdAt: createdAt ?? DateTime.utc(2026, 9, 7),
    environment: EnvironmentMetadata(
      cameraView: cameraView,
      supportType: supportType,
      supportSide: supportSide,
      movementSide: movementSide,
    ),
    selectedStartMs: 0,
    selectedEndMs: 1000,
    qualitySummary: _quality,
    normalizedTrajectory: List<BodyTrajectoryPoint>.generate(21, (index) {
      final progress = index / 20;
      return BodyTrajectoryPoint(
        progress: progress,
        timestampMs: index * 50,
        landmarks: _normalizedLandmarks(progress, trajectorySide)
            .map((point) => BodyTemplateLandmark(
                  x: point.dx,
                  y: point.dy,
                  confidence: 0.9,
                ))
            .toList(),
      );
    }),
    featureTrajectory: const [],
    existingSummary: const {
      'estimatedReps': 1,
      'symmetryScore': 1.0,
      'stabilityScore': 1.0,
      'mainJoints': [],
      'actionIntensity': [],
    },
  );
}

List<BodyTrajectorySample> _patientSamples({
  int frameCount = 11,
  BodySide side = BodySide.right,
  double scale = 0.2,
  Offset origin = const Offset(0.5, 0.6),
  int? deviatedJoint,
  List<int> deviatedJoints = const [],
  Offset deviation = Offset.zero,
}) {
  return List<BodyTrajectorySample>.generate(frameCount, (index) {
    final progress = frameCount == 1 ? 0.0 : index / (frameCount - 1);
    final normalized = _normalizedLandmarks(progress, side);
    final targets = {
      ...deviatedJoints,
      if (deviatedJoint != null) deviatedJoint
    };
    for (final joint in targets) {
      normalized[joint] += deviation;
    }
    return BodyTrajectorySample(
      timestampMs: index * 100,
      landmarks: normalized
          .map((point) => Offset(
                origin.dx + point.dx * scale,
                origin.dy + point.dy * scale,
              ))
          .toList(),
      scores: List<double>.filled(17, 0.9),
    );
  });
}

List<Offset> _normalizedLandmarks(double progress, BodySide movementSide) {
  final points = List<Offset>.filled(17, Offset.zero);
  points[0] = const Offset(0, -3);
  points[1] = const Offset(-0.1, -3.1);
  points[2] = const Offset(0.1, -3.1);
  points[3] = const Offset(-0.2, -3);
  points[4] = const Offset(0.2, -3);
  points[5] = const Offset(-0.5, -2);
  points[6] = const Offset(0.5, -2);
  points[7] = const Offset(-0.75, -1.2);
  points[8] = const Offset(0.75, -1.2);
  points[9] = const Offset(-0.8, -0.4);
  points[10] = const Offset(0.8, -0.4);
  points[11] = const Offset(-0.25, 0);
  points[12] = const Offset(0.25, 0);
  points[13] = const Offset(-0.25, 1.5);
  points[14] = const Offset(0.25, 1.5);
  points[15] = const Offset(-0.25, 3);
  points[16] = const Offset(0.25, 3);

  if (movementSide == BodySide.left) {
    points[13] = Offset(-0.25, 1.5 - progress * 1.8);
    points[15] = Offset(-0.25, 3 - progress * 2.0);
  } else {
    points[14] = Offset(0.25, 1.5 - progress * 1.8);
    points[16] = Offset(0.25, 3 - progress * 2.0);
  }
  return points;
}

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
