import 'dart:math' as math;

import '../hand_analysis_service.dart';
import '../hand_feature_extractor.dart';
import '../models/environment_metadata.dart';
import '../models/template_quality.dart';
import '../shared/trajectory_resampler.dart';
import 'hand_normalization.dart';

class HandTrajectoryPoint {
  HandTrajectoryPoint({
    required this.progress,
    required this.timestampMs,
    required List<NormalizedHandLandmark> landmarks,
  }) : landmarks = List<NormalizedHandLandmark>.unmodifiable(landmarks);

  final double progress;
  final int timestampMs;
  final List<NormalizedHandLandmark> landmarks;

  Map<String, dynamic> toJson() => {
        'progress': progress,
        'timestampMs': timestampMs,
        'landmarks': landmarks.map((point) => point.toJson()).toList(),
      };

  factory HandTrajectoryPoint.fromJson(Map<String, dynamic> json) =>
      HandTrajectoryPoint(
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        timestampMs: (json['timestampMs'] as num?)?.toInt() ?? 0,
        landmarks: (json['landmarks'] as List<dynamic>? ?? const [])
            .map((point) => NormalizedHandLandmark.fromJson(
                  Map<String, dynamic>.from(point as Map),
                ))
            .toList(),
      );
}

class HandMotionTemplate {
  HandMotionTemplate({
    required this.schemaVersion,
    required this.templateId,
    required this.templateName,
    required this.actionType,
    this.actionId,
    required this.createdAt,
    required this.environment,
    required this.selectedStartMs,
    required this.selectedEndMs,
    required this.qualitySummary,
    required List<HandTrajectoryPoint> normalizedTrajectory,
    required List<double> pinchDistanceSeries,
    required List<double> wristOrientation2dSeries,
    required List<double> actionIntensitySeries,
    required Map<String, dynamic> existingSummary,
    this.createdByTherapistId,
    this.patientId,
  })  : normalizedTrajectory =
            List<HandTrajectoryPoint>.unmodifiable(normalizedTrajectory),
        pinchDistanceSeries = List<double>.unmodifiable(pinchDistanceSeries),
        wristOrientation2dSeries =
            List<double>.unmodifiable(wristOrientation2dSeries),
        actionIntensitySeries =
            List<double>.unmodifiable(actionIntensitySeries),
        existingSummary = Map<String, dynamic>.unmodifiable(existingSummary);

  static const int currentSchemaVersion = 1;
  static const String modelType = 'hand';
  static const String templateSource = 'therapist_video';

  final int schemaVersion;
  final String templateId;
  final String templateName;
  final String actionType;
  final String? actionId;
  final DateTime createdAt;
  final EnvironmentMetadata environment;
  final int selectedStartMs;
  final int selectedEndMs;
  final TemplateQualitySummary qualitySummary;
  final List<HandTrajectoryPoint> normalizedTrajectory;
  final List<double> pinchDistanceSeries;

  /// wrist → middle MCP 的影像平面角度；這是 2D proxy，不是 3D 前臂旋轉。
  final List<double> wristOrientation2dSeries;

  final List<double> actionIntensitySeries;
  final Map<String, dynamic> existingSummary;
  final String? createdByTherapistId;
  final String? patientId;

  int get sampleCount => normalizedTrajectory.length;

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'templateId': templateId,
        'templateName': templateName,
        'actionType': actionType,
        if (actionId != null) 'actionId': actionId,
        'movementSide': environment.movementSide.name,
        'createdAt': createdAt.toIso8601String(),
        'modelType': modelType,
        'templateSource': templateSource,
        'cameraView': environment.cameraView.name,
        'supportType': environment.supportType.name,
        'supportSide': environment.supportSide.name,
        'selectedStartMs': selectedStartMs,
        'selectedEndMs': selectedEndMs,
        'sampleCount': sampleCount,
        'qualitySummary': qualitySummary.toJson(),
        'normalizedTrajectory':
            normalizedTrajectory.map((point) => point.toJson()).toList(),
        'pinchDistanceSeries': pinchDistanceSeries,
        'wristOrientation2dSeries': wristOrientation2dSeries,
        'actionIntensitySeries': actionIntensitySeries,
        'existingSummary': existingSummary,
        'createdByTherapistId': createdByTherapistId,
        'patientId': patientId,
        ...existingSummary,
      };

  factory HandMotionTemplate.fromJson(Map<String, dynamic> json) {
    final existing = Map<String, dynamic>.from(
      json['existingSummary'] as Map? ?? const <String, dynamic>{},
    );
    return HandMotionTemplate(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      templateId: json['templateId']?.toString() ?? '',
      templateName: json['templateName']?.toString() ?? '',
      actionType: json['actionType']?.toString() ?? '',
      actionId: json['actionId']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      environment: EnvironmentMetadata.fromJson(json),
      selectedStartMs: (json['selectedStartMs'] as num?)?.toInt() ?? 0,
      selectedEndMs: (json['selectedEndMs'] as num?)?.toInt() ?? 0,
      qualitySummary: TemplateQualitySummary.fromJson(
        Map<String, dynamic>.from(
          json['qualitySummary'] as Map? ?? const <String, dynamic>{},
        ),
      ),
      normalizedTrajectory:
          (json['normalizedTrajectory'] as List<dynamic>? ?? const [])
              .map((point) => HandTrajectoryPoint.fromJson(
                    Map<String, dynamic>.from(point as Map),
                  ))
              .toList(),
      pinchDistanceSeries: _doubleList(json['pinchDistanceSeries']),
      wristOrientation2dSeries: _doubleList(json['wristOrientation2dSeries']),
      actionIntensitySeries: _doubleList(json['actionIntensitySeries']),
      existingSummary: existing,
      createdByTherapistId: json['createdByTherapistId']?.toString(),
      patientId: json['patientId']?.toString(),
    );
  }

  static HandMotionTemplateBuildResult build({
    required HandVideoAnalysisResult analysis,
    required String templateName,
    required String actionType,
    String? actionId,
    required EnvironmentMetadata environment,
    String? createdByTherapistId,
    String? patientId,
    DateTime? createdAt,
    String? templateId,
  }) {
    final summary = analysis.summary;
    final normalized = analysis.attemptedFrames
        .where((frame) => frame.isValid)
        .map((frame) => HandNormalization.normalize(
              timestampMs: frame.timestampMs,
              landmarks: frame.landmarks!,
            ))
        .whereType<HandNormalizedFrame>()
        .toList();
    final movementIntensity = _movementIntensity(normalized);
    final quality = TemplateQualityValidator.evaluate(
      segmentDuration: analysis.segment.duration,
      attemptedFrameCount: analysis.attemptedFrameCount,
      validFrameCount: analysis.validFrameCount,
      normalizedFrameCount: normalized.length,
      movementIntensity: movementIntensity,
      detectedRepetitions: summary?.estimatedReps ?? 0,
    );

    if (!quality.isAcceptable || normalized.isEmpty || summary == null) {
      return HandMotionTemplateBuildResult(qualitySummary: quality);
    }

    final vectors = normalized.map((frame) {
      final values = <double>[];
      for (final landmark in frame.landmarks) {
        values
          ..add(landmark.x)
          ..add(landmark.y)
          ..add(landmark.z);
      }
      return TimedVectorSample(timestampMs: frame.timestampMs, values: values);
    }).toList();
    final resampled = TrajectoryResampler.resample(
      samples: vectors,
      startMs: analysis.segment.startMs,
      endMs: analysis.segment.endMs,
    );
    final trajectory = resampled.map((point) {
      final landmarks = List<NormalizedHandLandmark>.generate(
        HandNormalization.handLandmarkCount,
        (index) => NormalizedHandLandmark(
          point.values[index * 3],
          point.values[index * 3 + 1],
          point.values[index * 3 + 2],
        ),
      );
      return HandTrajectoryPoint(
        progress: point.progress,
        timestampMs: point.timestampMs,
        landmarks: landmarks,
      );
    }).toList();

    final pinchSeries = <double>[];
    final wristSeries = <double>[];
    final intensitySeries = <double>[];
    HandTrajectoryPoint? previous;
    for (final point in trajectory) {
      pinchSeries.add(_distance(point.landmarks[4], point.landmarks[8]));
      final wrist = point.landmarks[0];
      final middleMcp = point.landmarks[9];
      wristSeries.add(
        math.atan2(middleMcp.y - wrist.y, middleMcp.x - wrist.x) *
            180 /
            math.pi,
      );
      intensitySeries.add(
        previous == null ? 0 : _trajectoryDistance(previous, point),
      );
      previous = point;
    }

    final existingSummary = <String, dynamic>{
      'totalFrames': summary.totalFrames,
      'estimatedReps': summary.estimatedReps,
      'minPinchDistance': summary.minPinchDistance,
      'maxPinchDistance': summary.maxPinchDistance,
      'avgPinchDistance': summary.avgPinchDistance,
      // Legacy key retained for existing comparison. It is a 2D orientation proxy.
      'wristRotationRange': summary.wristRotationRange,
      'avgWristRotation': summary.avgWristRotation,
      'regularityScore': summary.regularityScore,
      'mainFingers': summary.mainFingerIndices
          .map((index) => {
                'index': index,
                'name': HandFeatureExtractor.fingerName(index),
                'movement': summary.fingerTotalMovement[index] ?? 0,
              })
          .toList(),
      'actionIntensity': summary.actionIntensity,
    };
    final now = createdAt ?? DateTime.now();
    final template = HandMotionTemplate(
      schemaVersion: currentSchemaVersion,
      templateId: templateId ?? 'hand_${now.microsecondsSinceEpoch}',
      templateName: templateName,
      actionType: actionType,
      actionId: actionId,
      createdAt: now,
      environment: environment,
      selectedStartMs: analysis.segment.startMs,
      selectedEndMs: analysis.segment.endMs,
      qualitySummary: quality,
      normalizedTrajectory: trajectory,
      pinchDistanceSeries: pinchSeries,
      wristOrientation2dSeries: wristSeries,
      actionIntensitySeries: intensitySeries,
      existingSummary: existingSummary,
      createdByTherapistId: createdByTherapistId,
      patientId: patientId,
    );
    return HandMotionTemplateBuildResult(
      qualitySummary: quality,
      template: template,
    );
  }

  static double _movementIntensity(List<HandNormalizedFrame> frames) {
    if (frames.length < 2) return 0;
    var movement = 0.0;
    var pairs = 0;
    for (var frameIndex = 1; frameIndex < frames.length; frameIndex++) {
      for (var joint = 0;
          joint < HandNormalization.handLandmarkCount;
          joint++) {
        movement += _distance(
          frames[frameIndex - 1].landmarks[joint],
          frames[frameIndex].landmarks[joint],
        );
        pairs++;
      }
    }
    return pairs == 0 ? 0 : movement / pairs;
  }

  static double _trajectoryDistance(
    HandTrajectoryPoint previous,
    HandTrajectoryPoint current,
  ) {
    var movement = 0.0;
    for (var i = 0; i < previous.landmarks.length; i++) {
      movement += _distance(previous.landmarks[i], current.landmarks[i]);
    }
    return movement / previous.landmarks.length;
  }

  static double _distance(
    NormalizedHandLandmark a,
    NormalizedHandLandmark b,
  ) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    final dz = a.z - b.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  static List<double> _doubleList(Object? value) =>
      (value as List<dynamic>? ?? const [])
          .map((item) => (item as num).toDouble())
          .toList();
}

class HandMotionTemplateBuildResult {
  const HandMotionTemplateBuildResult({
    required this.qualitySummary,
    this.template,
  });

  final TemplateQualitySummary qualitySummary;
  final HandMotionTemplate? template;
}
