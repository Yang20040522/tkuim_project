import 'dart:math' as math;
import 'dart:ui';

import '../analysis/body/body_normalization.dart';
import '../analysis/body/body_rep_trajectory_collector.dart';

/// Research-only, pseudonymous RTMPose sample. Never contains camera pixels.
class StandingKneeRaiseSample {
  const StandingKneeRaiseSample({
    required this.id,
    required this.subjectId,
    required this.movementSide,
    required this.cameraView,
    required this.capturedAt,
    required this.frames,
    required this.features,
  });

  static const actionId = 'standing_knee_raise';
  static const schemaVersion = 1;
  static const featureNames = <String>[
    'peak_leg_height',
    'minimum_hip_angle_deg',
    'minimum_knee_angle_deg',
    'peak_abs_trunk_lean_deg',
    'duration_seconds',
  ];

  final String id;
  final String subjectId;
  final String movementSide;
  final String cameraView;
  final DateTime capturedAt;
  final List<Map<String, Object>> frames;
  final List<double> features;

  Map<String, Object> toJson() => {
        'schemaVersion': schemaVersion,
        'actionId': actionId,
        'sampleId': id,
        'subjectId': subjectId,
        'movementSide': movementSide,
        'cameraView': cameraView,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'segment': {
          'startMs': frames.first['timestampMs']!,
          'endMs': frames.last['timestampMs']!
        },
        'featureNames': featureNames,
        'features': features,
        'frames': frames,
      };

  /// Returns null rather than writing a misleading/incomplete training sample.
  static StandingKneeRaiseSample? fromCompletedRep({
    required bool consentGranted,
    required String id,
    required String subjectId,
    required String movementSide,
    required String cameraView,
    required DateTime capturedAt,
    required List<BodyTrajectorySample> samples,
  }) {
    if (!consentGranted ||
        !RegExp(r'^[A-Za-z0-9_-]{3,40}$').hasMatch(subjectId.trim()) ||
        !const {'left', 'right'}.contains(movementSide) ||
        !const {'front', 'rear'}.contains(cameraView) ||
        samples.length < 4) {
      return null;
    }
    final start = samples.first.timestampMs;
    final end = samples.last.timestampMs;
    if (end - start < 300 || end - start > 8000) {
      return null;
    }

    final side = movementSide == 'left' ? [5, 11, 13, 15] : [6, 12, 14, 16];
    final requiredIndices = <int>{5, 6, 11, 12, ...side};
    final heights = <double>[];
    final hipAngles = <double>[];
    final kneeAngles = <double>[];
    final trunkLeans = <double>[];
    final frames = <Map<String, Object>>[];
    var previous = -1;
    for (final sample in samples) {
      if (sample.timestampMs <= previous ||
          sample.landmarks.length < 17 ||
          sample.scores.length < 17) {
        return null;
      }
      previous = sample.timestampMs;
      if (requiredIndices.any((i) =>
          !sample.landmarks[i].dx.isFinite ||
          !sample.landmarks[i].dy.isFinite ||
          !sample.scores[i].isFinite ||
          sample.scores[i] < BodyNormalization.confidenceThreshold ||
          sample.scores[i] > 1)) {
        return null;
      }
      if (sample.scores
          .take(17)
          .any((score) => !score.isFinite || score < 0 || score > 1)) {
        return null;
      }
      final normalized = BodyNormalization.normalize(
        timestampMs: sample.timestampMs,
        landmarks: sample.landmarks,
        scores: sample.scores,
      );
      if (normalized == null ||
          normalized.landmarks.any((p) => !p.dx.isFinite || !p.dy.isFinite)) {
        return null;
      }
      final p = normalized.landmarks;
      final hip = _angle(p[side[0]], p[side[1]], p[side[2]]);
      final knee = _angle(p[side[1]], p[side[2]], p[side[3]]);
      final shoulderMid = (p[5] + p[6]) / 2;
      final hipMid = (p[11] + p[12]) / 2;
      final lean =
          math.atan2(shoulderMid.dx - hipMid.dx, hipMid.dy - shoulderMid.dy) *
              180 /
              math.pi;
      if (!hip.isFinite || !knee.isFinite || !lean.isFinite) return null;
      heights.add(p[side[1]].dy - p[side[2]].dy);
      hipAngles.add(hip);
      kneeAngles.add(knee);
      trunkLeans.add(lean.abs());
      frames.add({
        'timestampMs': sample.timestampMs,
        'landmarks': List.generate(17, (i) => [p[i].dx, p[i].dy]),
        'confidence': sample.scores.take(17).toList(),
        'angles': {'hipDeg': hip, 'kneeDeg': knee, 'trunkLeanDeg': lean},
      });
    }
    final features = <double>[
      heights.reduce(math.max),
      hipAngles.reduce(math.min),
      kneeAngles.reduce(math.min),
      trunkLeans.reduce(math.max),
      (end - start) / 1000,
    ];
    if (features.any((value) => !value.isFinite)) return null;
    return StandingKneeRaiseSample(
      id: id,
      subjectId: subjectId.trim(),
      movementSide: movementSide,
      cameraView: cameraView,
      capturedAt: capturedAt,
      frames: frames,
      features: features,
    );
  }

  static double _angle(Offset a, Offset center, Offset b) {
    final u = a - center;
    final v = b - center;
    final denominator = u.distance * v.distance;
    if (denominator < 1e-6) return double.nan;
    return math.acos(
            ((u.dx * v.dx + u.dy * v.dy) / denominator).clamp(-1.0, 1.0)) *
        180 /
        math.pi;
  }
}
