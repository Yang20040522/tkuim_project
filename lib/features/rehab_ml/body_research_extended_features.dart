import 'dart:math' as math;

import '../../models/body_pose_observation.dart';
import 'body_research_feature_extractor.dart';

/// Offline research ablation only. Not added to sample uploads or rep counting.
class BodyResearchExtendedFeatures {
  static const version = 'body-aspect-extended-v1';
  static const names = [
    ...BodyResearchFeatureExtractor.featureNames,
    'hip_range_deg',
    'trunk_lean_std_deg',
    'time_to_peak_seconds',
  ];

  static List<double?> extract(List<BodyPoseObservation> frames, String side) {
    final baseline = BodyResearchFeatureExtractor.extract(frames, side);
    if (baseline.status != 'available') return List<double?>.filled(8, null);
    final valid = <(int, BodyProjectedFeatures)>[];
    for (final frame in frames) {
      final features = BodyResearchFeatureExtractor.frame(frame, side);
      if (features != null) valid.add((frame.receivedAtMs, features));
    }
    final mean = valid.map((f) => f.$2.trunkLeanDeg).reduce((a, b) => a + b) /
        valid.length;
    final variance = valid
            .map((f) => math.pow(f.$2.trunkLeanDeg - mean, 2))
            .reduce((a, b) => a + b) /
        valid.length;
    final peak = baseline.values[0];
    return [
      ...baseline.values,
      valid.map((f) => f.$2.hipDeg).reduce(math.max) -
          valid.map((f) => f.$2.hipDeg).reduce(math.min),
      math.sqrt(variance),
      (valid.firstWhere((f) => f.$2.legHeight == peak).$1 -
              frames.first.receivedAtMs) /
          1000,
    ];
  }
}
