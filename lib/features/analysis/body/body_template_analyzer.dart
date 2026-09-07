import 'dart:math' as math;

import '../models/environment_metadata.dart';
import '../shared/trajectory_resampler.dart';
import 'body_motion_template.dart';
import 'body_normalization.dart';
import 'body_rep_trajectory_collector.dart';
import 'body_template_selector.dart';

class BodyTemplateAnalysisResult {
  BodyTemplateAnalysisResult({
    required this.valid,
    required this.enoughData,
    this.overallScore,
    this.similarity,
    this.templateId,
    this.movementSide,
    this.jointScores = const {},
    this.biggestDeviations = const [],
    this.unavailableReason,
  })  : assert(
            overallScore == null || overallScore >= 0 && overallScore <= 100),
        assert(similarity == null || similarity >= 0 && similarity <= 1);

  final bool valid;
  final bool enoughData;
  final double? overallScore;
  final double? similarity;
  final String? templateId;
  final BodySide? movementSide;
  final Map<int, double> jointScores;
  final List<int> biggestDeviations;
  final String? unavailableReason;

  factory BodyTemplateAnalysisResult.unavailable({
    required bool enoughData,
    required String reason,
    String? templateId,
    BodySide? movementSide,
  }) =>
      BodyTemplateAnalysisResult(
        valid: false,
        enoughData: enoughData,
        templateId: templateId,
        movementSide: movementSide,
        unavailableReason: reason,
      );
}

class BodyTemplateAnalyzer {
  const BodyTemplateAnalyzer();

  /// Minimum normalized snapshots needed to represent a scored movement.
  static const int minimumNormalizedFrames = 4;

  /// Consecutive movement below this value (in shoulder-width units) is
  /// considered stationary only for leading/trailing trimming.
  static const double stationaryDeltaThreshold = 0.01;

  /// A weighted mean landmark error of this many shoulder widths maps to
  /// exp(-1) similarity. Keeping it named makes calibration testable.
  static const double similarityDistanceScale = 0.45;

  /// Reject comparisons dominated by low-confidence/missing joints.
  static const double minimumConfidenceCoverage = 0.55;

  /// A supported elbow/wrist is less diagnostic for knee-raise quality.
  static const double supportedArmWeightMultiplier = 0.25;

  /// The larger lower-limb motion must exceed the other by this ratio before
  /// anatomical movement side is inferred.
  static const double movementSideDominanceRatio = 1.15;

  BodyTemplateAnalysisResult analyzeBestMatching({
    required Iterable<BodyMotionTemplate> templates,
    required List<BodyTrajectorySample> patientSamples,
    required CameraView? currentCameraView,
    BodySide? movementSide,
  }) {
    final candidates =
        BodyTemplateSelector.standingKneeRaiseCandidates(templates);
    if (candidates.isEmpty) {
      return BodyTemplateAnalysisResult.unavailable(
        enoughData: patientSamples.length >= minimumNormalizedFrames,
        reason: '尚無站姿抬腳標準模板。',
      );
    }

    final prepared = _prepare(patientSamples);
    if (prepared.length < minimumNormalizedFrames) {
      return BodyTemplateAnalysisResult.unavailable(
        enoughData: false,
        reason: '本次動作可用骨架資料不足。',
      );
    }
    final resolvedMovementSide =
        movementSide ?? inferMovementSideFromNormalized(prepared);
    final template = BodyTemplateSelector.selectStandingKneeRaise(
      templates: candidates,
      movementSide: resolvedMovementSide,
    );
    if (template == null) {
      return BodyTemplateAnalysisResult.unavailable(
        enoughData: true,
        reason: '找不到符合本次動作側別的標準模板。',
        movementSide: resolvedMovementSide,
      );
    }
    return _analyzePrepared(
      template: template,
      normalizedFrames: prepared,
      movementSide: resolvedMovementSide ?? template.environment.movementSide,
      currentCameraView: currentCameraView,
    );
  }

  BodyTemplateAnalysisResult analyze({
    required BodyMotionTemplate template,
    required List<BodyTrajectorySample> patientSamples,
    required CameraView? currentCameraView,
    BodySide? movementSide,
  }) {
    final prepared = _prepare(patientSamples);
    if (prepared.length < minimumNormalizedFrames) {
      return BodyTemplateAnalysisResult.unavailable(
        enoughData: false,
        reason: '本次動作可用骨架資料不足。',
        templateId: template.templateId,
        movementSide: movementSide,
      );
    }
    return _analyzePrepared(
      template: template,
      normalizedFrames: prepared,
      movementSide: movementSide ??
          inferMovementSideFromNormalized(prepared) ??
          template.environment.movementSide,
      currentCameraView: currentCameraView,
    );
  }

  BodySide? inferMovementSideFromNormalized(
    List<BodyNormalizedFrame> frames,
  ) {
    if (frames.length < 2) return null;
    final leftMotion = _sideMotion(frames, const [11, 13, 15]);
    final rightMotion = _sideMotion(frames, const [12, 14, 16]);
    if (leftMotion > rightMotion * movementSideDominanceRatio) {
      return BodySide.left;
    }
    if (rightMotion > leftMotion * movementSideDominanceRatio) {
      return BodySide.right;
    }
    return null;
  }

  BodyTemplateAnalysisResult _analyzePrepared({
    required BodyMotionTemplate template,
    required List<BodyNormalizedFrame> normalizedFrames,
    required BodySide movementSide,
    required CameraView? currentCameraView,
  }) {
    if (currentCameraView == null) {
      return BodyTemplateAnalysisResult.unavailable(
        enoughData: true,
        reason: '目前鏡頭視角無法確認，暫不產生 AI 分數。',
        templateId: template.templateId,
        movementSide: movementSide,
      );
    }
    if (template.environment.cameraView != currentCameraView) {
      return BodyTemplateAnalysisResult.unavailable(
        enoughData: true,
        reason: '目前鏡頭視角與標準模板不一致。',
        templateId: template.templateId,
        movementSide: movementSide,
      );
    }
    if (template.normalizedTrajectory.length < 2) {
      return BodyTemplateAnalysisResult.unavailable(
        enoughData: true,
        reason: '標準模板軌跡資料不足。',
        templateId: template.templateId,
        movementSide: movementSide,
      );
    }

    final firstTimestamp = normalizedFrames.first.timestampMs;
    final lastTimestamp = normalizedFrames.last.timestampMs;
    if (lastTimestamp <= firstTimestamp) {
      return BodyTemplateAnalysisResult.unavailable(
        enoughData: false,
        reason: '本次動作時間資料不足。',
        templateId: template.templateId,
        movementSide: movementSide,
      );
    }

    final patientVectors = normalizedFrames.map((frame) {
      final values = <double>[];
      for (var index = 0;
          index < BodyNormalization.bodyLandmarkCount;
          index++) {
        values
          ..add(frame.landmarks[index].dx)
          ..add(frame.landmarks[index].dy)
          ..add(frame.scores[index]);
      }
      return TimedVectorSample(timestampMs: frame.timestampMs, values: values);
    }).toList();
    final patientTrajectory = TrajectoryResampler.resample(
      samples: patientVectors,
      startMs: firstTimestamp,
      endMs: lastTimestamp,
      pointCount: template.normalizedTrajectory.length,
    );

    var weightedDistance = 0.0;
    var comparableWeight = 0.0;
    var expectedWeight = 0.0;
    final jointDistances = <int, double>{};
    final jointWeights = <int, double>{};

    for (var pointIndex = 0;
        pointIndex < template.normalizedTrajectory.length;
        pointIndex++) {
      final standardPoint = template.normalizedTrajectory[pointIndex];
      final patientPoint = patientTrajectory[pointIndex];
      final landmarkCount = math.min(
        BodyNormalization.bodyLandmarkCount,
        standardPoint.landmarks.length,
      );
      for (var joint = 0; joint < landmarkCount; joint++) {
        final weight = _jointWeight(
          joint: joint,
          movementSide: movementSide,
          environment: template.environment,
        );
        expectedWeight += weight;
        final standard = standardPoint.landmarks[joint];
        final patientConfidence = patientPoint.values[joint * 3 + 2];
        if (standard.confidence < BodyNormalization.confidenceThreshold ||
            patientConfidence < BodyNormalization.confidenceThreshold) {
          continue;
        }
        final dx = patientPoint.values[joint * 3] - standard.x;
        final dy = patientPoint.values[joint * 3 + 1] - standard.y;
        final distance = math.sqrt(dx * dx + dy * dy);
        weightedDistance += distance * weight;
        comparableWeight += weight;
        jointDistances[joint] =
            (jointDistances[joint] ?? 0) + distance * weight;
        jointWeights[joint] = (jointWeights[joint] ?? 0) + weight;
      }
    }

    final coverage =
        expectedWeight == 0 ? 0 : comparableWeight / expectedWeight;
    if (comparableWeight == 0 || coverage < minimumConfidenceCoverage) {
      return BodyTemplateAnalysisResult.unavailable(
        enoughData: false,
        reason: '本次動作可信骨架點比例不足。',
        templateId: template.templateId,
        movementSide: movementSide,
      );
    }

    final meanDistance = weightedDistance / comparableWeight;
    final similarity =
        math.exp(-meanDistance / similarityDistanceScale).clamp(0.0, 1.0);
    final score = (similarity * 100).clamp(0.0, 100.0);
    final perJointScores = <int, double>{};
    for (final entry in jointDistances.entries) {
      final jointMean = entry.value / jointWeights[entry.key]!;
      perJointScores[entry.key] =
          (math.exp(-jointMean / similarityDistanceScale) * 100)
              .clamp(0.0, 100.0);
    }
    final deviations = perJointScores.keys.toList()
      ..sort((left, right) =>
          perJointScores[left]!.compareTo(perJointScores[right]!));

    return BodyTemplateAnalysisResult(
      valid: true,
      enoughData: true,
      overallScore: score,
      similarity: similarity,
      templateId: template.templateId,
      movementSide: movementSide,
      jointScores: Map<int, double>.unmodifiable(perJointScores),
      biggestDeviations: List<int>.unmodifiable(deviations.take(3)),
    );
  }

  List<BodyNormalizedFrame> _prepare(
    List<BodyTrajectorySample> samples,
  ) {
    final normalized = samples
        .map((sample) => BodyNormalization.normalize(
              timestampMs: sample.timestampMs,
              landmarks: sample.landmarks,
              scores: sample.scores,
            ))
        .whereType<BodyNormalizedFrame>()
        .toList()
      ..sort((left, right) => left.timestampMs.compareTo(right.timestampMs));
    return _trimStationaryEdges(normalized);
  }

  List<BodyNormalizedFrame> _trimStationaryEdges(
    List<BodyNormalizedFrame> frames,
  ) {
    if (frames.length < minimumNormalizedFrames) return frames;
    var firstMotionPair = -1;
    var lastMotionPair = -1;
    for (var index = 1; index < frames.length; index++) {
      final delta = _frameMotion(frames[index - 1], frames[index]);
      if (delta > stationaryDeltaThreshold) {
        if (firstMotionPair < 0) firstMotionPair = index;
        lastMotionPair = index;
      }
    }
    if (firstMotionPair < 0) return frames;
    final start = math.max(0, firstMotionPair - 1);
    final endExclusive = math.min(frames.length, lastMotionPair + 1);
    return frames.sublist(start, endExclusive);
  }

  double _frameMotion(BodyNormalizedFrame left, BodyNormalizedFrame right) {
    const tracked = [5, 6, 11, 12, 13, 14, 15, 16];
    var total = 0.0;
    for (final joint in tracked) {
      total += (right.landmarks[joint] - left.landmarks[joint]).distance;
    }
    return total / tracked.length;
  }

  double _sideMotion(List<BodyNormalizedFrame> frames, List<int> joints) {
    var total = 0.0;
    for (var frameIndex = 1; frameIndex < frames.length; frameIndex++) {
      for (final joint in joints) {
        total += (frames[frameIndex].landmarks[joint] -
                frames[frameIndex - 1].landmarks[joint])
            .distance;
      }
    }
    return total;
  }

  double _jointWeight({
    required int joint,
    required BodySide movementSide,
    required EnvironmentMetadata environment,
  }) {
    var weight = switch (joint) {
      5 || 6 => 2.0,
      11 || 12 => 2.5,
      13 || 14 => 1.0,
      15 || 16 => 0.8,
      7 || 8 => 0.4,
      9 || 10 => 0.3,
      0 => 0.25,
      _ => 0.1,
    };

    final isMovementJoint = switch (movementSide) {
      BodySide.left => joint == 11 || joint == 13 || joint == 15,
      BodySide.right => joint == 12 || joint == 14 || joint == 16,
      BodySide.both => joint >= 11 && joint <= 16,
      BodySide.none => false,
    };
    if (isMovementJoint) {
      weight = switch (joint) {
        11 || 12 => 4.0,
        13 || 14 => 5.0,
        15 || 16 => 4.0,
        _ => weight,
      };
    }

    if (environment.supportType != SupportType.none &&
        _isSupportedArmJoint(joint, environment.supportSide)) {
      weight *= supportedArmWeightMultiplier;
    }
    return weight;
  }

  bool _isSupportedArmJoint(int joint, BodySide supportSide) =>
      switch (supportSide) {
        BodySide.left => joint == 7 || joint == 9,
        BodySide.right => joint == 8 || joint == 10,
        BodySide.both => joint == 7 || joint == 8 || joint == 9 || joint == 10,
        BodySide.none => false,
      };
}
