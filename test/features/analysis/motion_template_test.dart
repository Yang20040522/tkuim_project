import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_body/features/analysis/body/body_motion_template.dart';
import 'package:flutter_body/features/analysis/hand/hand_motion_template.dart';
import 'package:flutter_body/features/analysis/hand_analysis_service.dart';
import 'package:flutter_body/features/analysis/hand_feature_extractor.dart';
import 'package:flutter_body/features/analysis/models/environment_metadata.dart';
import 'package:flutter_body/features/analysis/models/video_segment.dart';
import 'package:flutter_body/features/analysis/motion_feature_extractor.dart';
import 'package:flutter_body/features/analysis/video_analysis_service.dart';
import 'package:flutter_body/services/mediapipe_service.dart';

void main() {
  const segment = VideoSegment(
    startTime: Duration.zero,
    endTime: Duration(milliseconds: 1200),
  );
  const environment = EnvironmentMetadata(
    cameraView: CameraView.oblique,
    supportType: SupportType.chair,
    supportSide: BodySide.left,
    movementSide: BodySide.right,
  );
  final createdAt = DateTime.utc(2026, 9, 7, 1, 2, 3);

  test('BodyMotionTemplate builds 21 points and survives JSON round-trip', () {
    final analysis = BodyVideoAnalysisResult(
      segment: segment,
      attemptedFrames: [
        _bodyFrame(0, 0),
        _bodyFrame(400, 0.08),
        _bodyFrame(800, 0.16),
        _bodyFrame(1200, 0.24),
      ],
      summary: const MotionAnalysisResult(
        mainJointIndices: [10],
        jointTotalMovement: {10: 0.24},
        actionIntensity: [0, 0.08, 0.08, 0.08],
        estimatedReps: 1,
        symmetryScore: 0.75,
        stabilityScore: 0.8,
      ),
    );

    final build = BodyMotionTemplate.build(
      analysis: analysis,
      templateName: '右側抬手',
      actionType: 'standing_knee_raise',
      actionId: 'standing_knee_raise',
      environment: environment,
      createdByTherapistId: 'therapist-1',
      patientId: 'patient-1',
      createdAt: createdAt,
      templateId: 'body-test',
    );

    expect(build.qualitySummary.isAcceptable, isTrue);
    expect(build.template, isNotNull);
    expect(build.template!.normalizedTrajectory, hasLength(21));
    expect(build.template!.featureTrajectory, hasLength(21));
    final json = build.template!.toJson();
    expect(json['modelType'], 'body');
    expect(json['actionId'], 'standing_knee_raise');
    expect(json['templateSource'], 'therapist_video');
    expect(json['estimatedReps'], 1, reason: 'legacy field stays top-level');
    expect(BodyMotionTemplate.fromJson(json).toJson(), json);
  });

  test('HandMotionTemplate keeps xyz series and survives JSON round-trip', () {
    final analysis = HandVideoAnalysisResult(
      segment: segment,
      attemptedFrames: [
        _handFrame(0, 0),
        _handFrame(400, 0.08),
        _handFrame(800, 0.16),
        _handFrame(1200, 0.24),
      ],
      summary: const HandAnalysisResult(
        mainFingerIndices: [4, 8],
        fingerTotalMovement: {4: 0.24, 8: 0.12},
        estimatedReps: 1,
        minPinchDistance: 0.1,
        maxPinchDistance: 0.4,
        avgPinchDistance: 0.25,
        wristRotationRange: 25,
        avgWristRotation: 10,
        regularityScore: 0.8,
        actionIntensity: [0, 0.08, 0.08, 0.08],
        pinchDistanceSeries: [0.1, 0.2, 0.3, 0.4],
        wristOrientation2dSeries: [0, 5, 10, 15],
        totalFrames: 4,
      ),
    );

    final build = HandMotionTemplate.build(
      analysis: analysis,
      templateName: '側捏',
      actionType: 'side_pinch',
      actionId: 'side_pinch',
      environment: environment,
      createdByTherapistId: 'therapist-1',
      patientId: 'patient-1',
      createdAt: createdAt,
      templateId: 'hand-test',
    );

    expect(build.qualitySummary.isAcceptable, isTrue);
    expect(build.template, isNotNull);
    expect(build.template!.normalizedTrajectory, hasLength(21));
    expect(build.template!.normalizedTrajectory.first.landmarks, hasLength(21));
    expect(build.template!.pinchDistanceSeries, hasLength(21));
    expect(build.template!.wristOrientation2dSeries, hasLength(21));
    expect(build.template!.actionIntensitySeries, hasLength(21));
    final json = build.template!.toJson();
    expect(json['modelType'], 'hand');
    expect(json['actionId'], 'side_pinch');
    expect(json['templateSource'], 'therapist_video');
    expect(json['regularityScore'], 0.8,
        reason: 'legacy field stays top-level');
    expect(HandMotionTemplate.fromJson(json).toJson(), json);
  });
}

BodyVideoFrameSample _bodyFrame(int timestampMs, double wristShift) {
  final landmarks = List<Offset>.filled(17, const Offset(0.5, 0.5));
  landmarks[5] = const Offset(0.4, 0.3);
  landmarks[6] = const Offset(0.6, 0.3);
  landmarks[11] = const Offset(0.4, 0.7);
  landmarks[12] = const Offset(0.6, 0.7);
  landmarks[10] = Offset(0.7 + wristShift, 0.5);
  return BodyVideoFrameSample(
    timestampMs: timestampMs,
    landmarks: landmarks,
    scores: List<double>.filled(17, 0.9),
  );
}

HandVideoFrameSample _handFrame(int timestampMs, double thumbShift) {
  final landmarks = List<Landmark>.generate(
    21,
    (index) => Landmark(0.5 + index * 0.002, 0.5, index * 0.001),
  );
  landmarks[0] = const Landmark(0.5, 0.5, 0);
  landmarks[5] = const Landmark(0.6, 0.5, 0);
  landmarks[17] = const Landmark(0.4, 0.5, 0);
  landmarks[9] = const Landmark(0.5, 0.3, 0.02);
  landmarks[4] = Landmark(0.58 + thumbShift, 0.4, 0.03);
  landmarks[8] = const Landmark(0.7, 0.35, 0.06);
  return HandVideoFrameSample(timestampMs: timestampMs, landmarks: landmarks);
}
