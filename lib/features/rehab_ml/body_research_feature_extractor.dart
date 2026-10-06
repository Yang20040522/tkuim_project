import 'dart:math' as math;
import 'dart:ui';

import '../../models/body_pose_observation.dart';

/// Research geometry only. Does not participate in rehabilitation counting.
class BodyResearchFeatureExtractor {
  static const version = 'standing-knee-raise-aspect-2d-v2';
  static const modelInputVersion = 'body-attempt-features-v1';
  static const actionDefinitionVersion = 'standing-knee-raise-body-v2';
  static const featureNames = [
    'peak_leg_height',
    'minimum_hip_angle_deg',
    'minimum_knee_angle_deg',
    'peak_abs_trunk_lean_deg',
    'duration_seconds',
  ];

  static BodyProjectedFeatures? frame(
      BodyPoseObservation observation, String side) {
    if (!const {'left', 'right'}.contains(side)) return null;
    final shoulder = observation.pixelPoint(side == 'left' ? 5 : 6);
    final hip = observation.pixelPoint(side == 'left' ? 11 : 12);
    final knee = observation.pixelPoint(side == 'left' ? 13 : 14);
    final ankle = observation.pixelPoint(side == 'left' ? 15 : 16);
    final ls = observation.pixelPoint(5), rs = observation.pixelPoint(6);
    final lh = observation.pixelPoint(11), rh = observation.pixelPoint(12);
    if ([shoulder, hip, knee, ankle, ls, rs, lh, rh].any((p) => p == null)) {
      return null;
    }
    final top = (ls! + rs!) / 2;
    final bottom = (lh! + rh!) / 2;
    final torso = (top - bottom).distance;
    if (torso <= 1e-6) return null;
    final hipAngle = _angle(shoulder!, hip!, knee!);
    final kneeAngle = _angle(hip, knee, ankle!);
    if (hipAngle == null || kneeAngle == null) return null;
    return BodyProjectedFeatures(
      legHeight: math.max(0, (hip.dy - knee.dy) / torso),
      hipDeg: hipAngle,
      kneeDeg: kneeAngle,
      trunkLeanDeg:
          math.atan2(top.dx - bottom.dx, bottom.dy - top.dy) * 180 / math.pi,
    );
  }

  static double? _angle(Offset a, Offset b, Offset c) {
    final u = a - b, v = c - b;
    final denominator = u.distance * v.distance;
    if (denominator < 1e-6) return null;
    return math.acos(((u.dx * v.dx + u.dy * v.dy) / denominator).clamp(-1, 1)) *
        180 /
        math.pi;
  }

  static BodyAttemptFeatures extract(
      List<BodyPoseObservation> frames, String side) {
    final valid = frames
        .map((f) => frame(f, side))
        .whereType<BodyProjectedFeatures>()
        .toList();
    final ratio = frames.isEmpty ? 0.0 : valid.length / frames.length;
    final available = valid.length >= 4 &&
        ratio >= 0.6 &&
        frames.last.receivedAtMs > frames.first.receivedAtMs;
    return BodyAttemptFeatures(
      validFrameRatio: ratio,
      values: !available
          ? List<double?>.filled(5, null)
          : [
              valid.map((f) => f.legHeight).reduce(math.max),
              valid.map((f) => f.hipDeg).reduce(math.min),
              valid.map((f) => f.kneeDeg).reduce(math.min),
              valid.map((f) => f.trunkLeanDeg.abs()).reduce(math.max),
              (frames.last.receivedAtMs - frames.first.receivedAtMs) / 1000,
            ],
    );
  }
}

class BodyProjectedFeatures {
  const BodyProjectedFeatures(
      {required this.legHeight,
      required this.hipDeg,
      required this.kneeDeg,
      required this.trunkLeanDeg});
  final double legHeight, hipDeg, kneeDeg, trunkLeanDeg;
  Map<String, double> toJson() => {
        'hipDeg': hipDeg,
        'kneeDeg': kneeDeg,
        'trunkLeanDeg': trunkLeanDeg,
        'legHeight': legHeight
      };
}

class BodyAttemptFeatures {
  BodyAttemptFeatures(
      {required List<double?> values, required this.validFrameRatio})
      : values = List.unmodifiable(values);
  final List<double?> values;
  final double validFrameRatio;
  String get status =>
      values.every((v) => v != null) ? 'available' : 'unavailable';
}
