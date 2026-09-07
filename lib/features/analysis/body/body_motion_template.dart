import 'dart:math' as math;
import 'dart:ui';

import '../models/environment_metadata.dart';
import '../models/template_quality.dart';
import '../shared/trajectory_resampler.dart';
import '../video_analysis_service.dart';
import 'body_normalization.dart';

class BodyTemplateLandmark {
  const BodyTemplateLandmark({
    required this.x,
    required this.y,
    required this.confidence,
  });

  final double x;
  final double y;
  final double confidence;

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'confidence': confidence,
      };

  factory BodyTemplateLandmark.fromJson(Map<String, dynamic> json) =>
      BodyTemplateLandmark(
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      );
}

class BodyTrajectoryPoint {
  BodyTrajectoryPoint({
    required this.progress,
    required this.timestampMs,
    required List<BodyTemplateLandmark> landmarks,
  }) : landmarks = List<BodyTemplateLandmark>.unmodifiable(landmarks);

  final double progress;
  final int timestampMs;
  final List<BodyTemplateLandmark> landmarks;

  Map<String, dynamic> toJson() => {
        'progress': progress,
        'timestampMs': timestampMs,
        'landmarks': landmarks.map((point) => point.toJson()).toList(),
      };

  factory BodyTrajectoryPoint.fromJson(Map<String, dynamic> json) =>
      BodyTrajectoryPoint(
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        timestampMs: (json['timestampMs'] as num?)?.toInt() ?? 0,
        landmarks: (json['landmarks'] as List<dynamic>? ?? const [])
            .map((point) => BodyTemplateLandmark.fromJson(
                  Map<String, dynamic>.from(point as Map),
                ))
            .toList(),
      );
}

class BodyFeaturePoint {
  const BodyFeaturePoint({
    required this.progress,
    required this.hipAngle,
    required this.kneeAngle,
    required this.trunkLean,
    required this.legRelativeHeight,
    required this.shoulderTilt,
    required this.actionIntensity,
  });

  final double progress;
  final double hipAngle;
  final double kneeAngle;
  final double trunkLean;
  final double legRelativeHeight;
  final double shoulderTilt;
  final double actionIntensity;

  Map<String, dynamic> toJson() => {
        'progress': progress,
        'hipAngle': hipAngle,
        'kneeAngle': kneeAngle,
        'trunkLean': trunkLean,
        'legRelativeHeight': legRelativeHeight,
        'shoulderTilt': shoulderTilt,
        'actionIntensity': actionIntensity,
      };

  factory BodyFeaturePoint.fromJson(Map<String, dynamic> json) =>
      BodyFeaturePoint(
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        hipAngle: (json['hipAngle'] as num?)?.toDouble() ?? 0,
        kneeAngle: (json['kneeAngle'] as num?)?.toDouble() ?? 0,
        trunkLean: (json['trunkLean'] as num?)?.toDouble() ?? 0,
        legRelativeHeight: (json['legRelativeHeight'] as num?)?.toDouble() ?? 0,
        shoulderTilt: (json['shoulderTilt'] as num?)?.toDouble() ?? 0,
        actionIntensity: (json['actionIntensity'] as num?)?.toDouble() ?? 0,
      );
}

class BodyMotionTemplate {
  BodyMotionTemplate({
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
    required List<BodyTrajectoryPoint> normalizedTrajectory,
    required List<BodyFeaturePoint> featureTrajectory,
    required Map<String, dynamic> existingSummary,
    this.createdByTherapistId,
    this.patientId,
  })  : normalizedTrajectory =
            List<BodyTrajectoryPoint>.unmodifiable(normalizedTrajectory),
        featureTrajectory =
            List<BodyFeaturePoint>.unmodifiable(featureTrajectory),
        existingSummary = Map<String, dynamic>.unmodifiable(existingSummary);

  static const int currentSchemaVersion = 1;
  static const String modelType = 'body';
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
  final List<BodyTrajectoryPoint> normalizedTrajectory;
  final List<BodyFeaturePoint> featureTrajectory;
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
        'featureTrajectory':
            featureTrajectory.map((point) => point.toJson()).toList(),
        'existingSummary': existingSummary,
        'createdByTherapistId': createdByTherapistId,
        'patientId': patientId,
        ...existingSummary,
      };

  factory BodyMotionTemplate.fromJson(Map<String, dynamic> json) {
    final existing = Map<String, dynamic>.from(
      json['existingSummary'] as Map? ?? const <String, dynamic>{},
    );
    return BodyMotionTemplate(
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
              .map((point) => BodyTrajectoryPoint.fromJson(
                    Map<String, dynamic>.from(point as Map),
                  ))
              .toList(),
      featureTrajectory:
          (json['featureTrajectory'] as List<dynamic>? ?? const [])
              .map((point) => BodyFeaturePoint.fromJson(
                    Map<String, dynamic>.from(point as Map),
                  ))
              .toList(),
      existingSummary: existing,
      createdByTherapistId: json['createdByTherapistId']?.toString(),
      patientId: json['patientId']?.toString(),
    );
  }

  static BodyMotionTemplateBuildResult build({
    required BodyVideoAnalysisResult analysis,
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
        .map((frame) => BodyNormalization.normalize(
              timestampMs: frame.timestampMs,
              landmarks: frame.landmarks!,
              scores: frame.scores!,
            ))
        .whereType<BodyNormalizedFrame>()
        .toList();
    final movementIntensity = _movementIntensity(normalized);
    final averageConfidence = normalized.isEmpty
        ? 0.0
        : normalized
                .map((frame) => frame.keyJointConfidence)
                .reduce((a, b) => a + b) /
            normalized.length;
    final quality = TemplateQualityValidator.evaluate(
      segmentDuration: analysis.segment.duration,
      attemptedFrameCount: analysis.attemptedFrameCount,
      validFrameCount: analysis.validFrameCount,
      normalizedFrameCount: normalized.length,
      movementIntensity: movementIntensity,
      detectedRepetitions: summary?.estimatedReps ?? 0,
      averageBodyConfidence: averageConfidence,
    );

    if (!quality.isAcceptable || normalized.isEmpty || summary == null) {
      return BodyMotionTemplateBuildResult(qualitySummary: quality);
    }

    final vectors = normalized.map((frame) {
      final values = <double>[];
      for (var i = 0; i < BodyNormalization.bodyLandmarkCount; i++) {
        values
          ..add(frame.landmarks[i].dx)
          ..add(frame.landmarks[i].dy)
          ..add(frame.scores[i]);
      }
      return TimedVectorSample(timestampMs: frame.timestampMs, values: values);
    }).toList();
    final resampled = TrajectoryResampler.resample(
      samples: vectors,
      startMs: analysis.segment.startMs,
      endMs: analysis.segment.endMs,
    );
    final trajectory = resampled.map((point) {
      final landmarks = List<BodyTemplateLandmark>.generate(
        BodyNormalization.bodyLandmarkCount,
        (index) => BodyTemplateLandmark(
          x: point.values[index * 3],
          y: point.values[index * 3 + 1],
          confidence: point.values[index * 3 + 2].clamp(0.0, 1.0),
        ),
      );
      return BodyTrajectoryPoint(
        progress: point.progress,
        timestampMs: point.timestampMs,
        landmarks: landmarks,
      );
    }).toList();
    final features =
        _buildFeatureTrajectory(trajectory, environment.movementSide);
    final existingSummary = <String, dynamic>{
      'totalFrames': analysis.validFrameCount,
      'estimatedReps': summary.estimatedReps,
      'symmetryScore': summary.symmetryScore,
      'stabilityScore': summary.stabilityScore,
      'mainJoints': summary.mainJointIndices
          .map((index) => {
                'index': index,
                'name': _jointName(index),
                'movement': summary.jointTotalMovement[index] ?? 0,
              })
          .toList(),
      'actionIntensity': summary.actionIntensity,
    };
    final now = createdAt ?? DateTime.now();
    final template = BodyMotionTemplate(
      schemaVersion: currentSchemaVersion,
      templateId: templateId ?? 'body_${now.microsecondsSinceEpoch}',
      templateName: templateName,
      actionType: actionType,
      actionId: actionId,
      createdAt: now,
      environment: environment,
      selectedStartMs: analysis.segment.startMs,
      selectedEndMs: analysis.segment.endMs,
      qualitySummary: quality,
      normalizedTrajectory: trajectory,
      featureTrajectory: features,
      existingSummary: existingSummary,
      createdByTherapistId: createdByTherapistId,
      patientId: patientId,
    );
    return BodyMotionTemplateBuildResult(
      qualitySummary: quality,
      template: template,
    );
  }

  static List<BodyFeaturePoint> _buildFeatureTrajectory(
    List<BodyTrajectoryPoint> trajectory,
    BodySide movementSide,
  ) {
    final result = <BodyFeaturePoint>[];
    BodyTrajectoryPoint? previous;
    for (final point in trajectory) {
      final landmarks = point.landmarks
          .map((landmark) => Offset(landmark.x, landmark.y))
          .toList();
      final sideIndices = switch (movementSide) {
        BodySide.left => const [
            [5, 11, 13, 15]
          ],
        BodySide.right => const [
            [6, 12, 14, 16]
          ],
        BodySide.none || BodySide.both => const [
            [5, 11, 13, 15],
            [6, 12, 14, 16],
          ],
      };
      final hipAngles = <double>[];
      final kneeAngles = <double>[];
      final legHeights = <double>[];
      for (final indices in sideIndices) {
        hipAngles.add(_angle(
          landmarks[indices[0]],
          landmarks[indices[1]],
          landmarks[indices[2]],
        ));
        kneeAngles.add(_angle(
          landmarks[indices[1]],
          landmarks[indices[2]],
          landmarks[indices[3]],
        ));
        legHeights.add(landmarks[indices[1]].dy - landmarks[indices[2]].dy);
      }
      final shoulderMid = Offset(
        (landmarks[5].dx + landmarks[6].dx) / 2,
        (landmarks[5].dy + landmarks[6].dy) / 2,
      );
      final hipMid = Offset(
        (landmarks[11].dx + landmarks[12].dx) / 2,
        (landmarks[11].dy + landmarks[12].dy) / 2,
      );
      result.add(BodyFeaturePoint(
        progress: point.progress,
        hipAngle: _average(hipAngles),
        kneeAngle: _average(kneeAngles),
        trunkLean: math.atan2(
              shoulderMid.dx - hipMid.dx,
              hipMid.dy - shoulderMid.dy,
            ) *
            180 /
            math.pi,
        legRelativeHeight: _average(legHeights),
        shoulderTilt: (landmarks[5].dy - landmarks[6].dy).abs(),
        actionIntensity:
            previous == null ? 0 : _trajectoryDistance(previous, point),
      ));
      previous = point;
    }
    return result;
  }

  static double _movementIntensity(List<BodyNormalizedFrame> frames) {
    if (frames.length < 2) return 0;
    var movement = 0.0;
    var pairs = 0;
    for (var frameIndex = 1; frameIndex < frames.length; frameIndex++) {
      for (var joint = 0;
          joint < BodyNormalization.bodyLandmarkCount;
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
    BodyTrajectoryPoint previous,
    BodyTrajectoryPoint current,
  ) {
    var sum = 0.0;
    for (var i = 0; i < previous.landmarks.length; i++) {
      sum += _distance(
        Offset(previous.landmarks[i].x, previous.landmarks[i].y),
        Offset(current.landmarks[i].x, current.landmarks[i].y),
      );
    }
    return sum / previous.landmarks.length;
  }

  static double _angle(Offset a, Offset center, Offset c) {
    final ab = a - center;
    final cb = c - center;
    final denominator = ab.distance * cb.distance;
    if (denominator < 1e-9) return 0;
    final cosine = (ab.dx * cb.dx + ab.dy * cb.dy) / denominator;
    return math.acos(cosine.clamp(-1.0, 1.0)) * 180 / math.pi;
  }

  static double _distance(Offset a, Offset b) => (a - b).distance;

  static double _average(List<double> values) =>
      values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

  static String _jointName(int index) {
    const names = {
      0: '鼻',
      5: '左肩',
      6: '右肩',
      7: '左肘',
      8: '右肘',
      9: '左腕',
      10: '右腕',
      11: '左髖',
      12: '右髖',
      13: '左膝',
      14: '右膝',
      15: '左踝',
      16: '右踝',
    };
    return names[index] ?? '關節$index';
  }
}

class BodyMotionTemplateBuildResult {
  const BodyMotionTemplateBuildResult({
    required this.qualitySummary,
    this.template,
  });

  final TemplateQualitySummary qualitySummary;
  final BodyMotionTemplate? template;
}
