import 'dart:math' as math;

import 'models/joint_angle_frame.dart';
import 'models/pose_frame.dart';

export 'models/joint_angle_frame.dart';

/// Geometric 3D angles from WORLD landmarks only; not clinical ROM evaluation.
class JointAngleCalculator {
  const JointAngleCalculator({this.minConfidence = 0.5});

  final double minConfidence;

  JointAngleFrame calculate(PoseFrame frame) {
    final world = frame.worldLandmarks;
    final values = <JointMeasurementType, double?>{};
    for (final entry in _triples.entries) {
      values[entry.key] = angleDegrees(
        world[entry.value[0]],
        world[entry.value[1]],
        world[entry.value[2]],
      );
    }
    return JointAngleFrame(timestampMs: frame.timestampMs, angles: values);
  }

  /// Angle ABC in degrees. Callers supply unmodified world coordinates only.
  double? angleDegrees(PoseLandmark? a, PoseLandmark? b, PoseLandmark? c) {
    if (a == null ||
        b == null ||
        c == null ||
        !a.isReliable(minConfidence) ||
        !b.isReliable(minConfidence) ||
        !c.isReliable(minConfidence)) {
      return null;
    }
    final ax = a.x - b.x;
    final ay = a.y - b.y;
    final az = a.z - b.z;
    final cx = c.x - b.x;
    final cy = c.y - b.y;
    final cz = c.z - b.z;
    final aLength = math.sqrt(ax * ax + ay * ay + az * az);
    final cLength = math.sqrt(cx * cx + cy * cy + cz * cz);
    if (!aLength.isFinite ||
        !cLength.isFinite ||
        aLength <= 1e-9 ||
        cLength <= 1e-9) {
      return null;
    }
    final dot =
        (ax / aLength) * (cx / cLength) +
        (ay / aLength) * (cy / cLength) +
        (az / aLength) * (cz / cLength);
    if (!dot.isFinite) return null;
    return math.acos(dot.clamp(-1.0, 1.0)) * 180 / math.pi;
  }

  static const _triples = <JointMeasurementType, List<PoseLandmarkType>>{
    JointMeasurementType.leftElbow: [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftWrist,
    ],
    JointMeasurementType.rightElbow: [
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.rightWrist,
    ],
    JointMeasurementType.leftKnee: [
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.leftAnkle,
    ],
    JointMeasurementType.rightKnee: [
      PoseLandmarkType.rightHip,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.rightAnkle,
    ],
    JointMeasurementType.leftShoulderBodyAngle: [
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftHip,
    ],
    JointMeasurementType.rightShoulderBodyAngle: [
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightHip,
    ],
    JointMeasurementType.leftHipBodyAngle: [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee,
    ],
    JointMeasurementType.rightHipBodyAngle: [
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.rightKnee,
    ],
  };
}
