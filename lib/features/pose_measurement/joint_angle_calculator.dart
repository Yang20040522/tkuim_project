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
    final bodyFrame = _BodyRelativeFrame.tryCreate(
      world,
      minConfidence: minConfidence,
    );
    values[JointMeasurementType.leftShoulderAbduction] =
        bodyFrame?.shoulderElevation(
      world[PoseLandmarkType.leftShoulder],
      world[PoseLandmarkType.leftElbow],
      direction: -bodyFrame.right,
      minConfidence: minConfidence,
    );
    values[JointMeasurementType.rightShoulderAbduction] =
        bodyFrame?.shoulderElevation(
      world[PoseLandmarkType.rightShoulder],
      world[PoseLandmarkType.rightElbow],
      direction: bodyFrame.right,
      minConfidence: minConfidence,
    );
    values[JointMeasurementType.leftShoulderFlexion] =
        bodyFrame?.shoulderElevation(
      world[PoseLandmarkType.leftShoulder],
      world[PoseLandmarkType.leftElbow],
      direction: bodyFrame.forward,
      minConfidence: minConfidence,
    );
    values[JointMeasurementType.rightShoulderFlexion] =
        bodyFrame?.shoulderElevation(
      world[PoseLandmarkType.rightShoulder],
      world[PoseLandmarkType.rightElbow],
      direction: bodyFrame.forward,
      minConfidence: minConfidence,
    );
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
    final dot = (ax / aLength) * (cx / cLength) +
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

/// Torso-relative orthonormal axes built exclusively from world landmarks.
///
/// [right] points toward the person's anatomical right, [up] toward the head,
/// and [forward] approximates the anterior direction. MediaPipe world X/Y/Z
/// remain untouched; preview mirroring and screen coordinates never enter this
/// frame. The cross-product order matches MediaPipe's front-facing handedness:
/// forward = up × right.
class _BodyRelativeFrame {
  const _BodyRelativeFrame({
    required this.right,
    required this.up,
    required this.forward,
  });

  final _Vector3 right;
  final _Vector3 up;
  final _Vector3 forward;

  static _BodyRelativeFrame? tryCreate(
    Map<PoseLandmarkType, PoseLandmark> world, {
    required double minConfidence,
  }) {
    final leftShoulder = world[PoseLandmarkType.leftShoulder];
    final rightShoulder = world[PoseLandmarkType.rightShoulder];
    final leftHip = world[PoseLandmarkType.leftHip];
    final rightHip = world[PoseLandmarkType.rightHip];
    final requiredLandmarks = [
      leftShoulder,
      rightShoulder,
      leftHip,
      rightHip,
    ];
    if (requiredLandmarks.any(
      (landmark) => landmark == null || !landmark.isReliable(minConfidence),
    )) {
      return null;
    }

    final leftShoulderPoint = _Vector3.from(leftShoulder!);
    final rightShoulderPoint = _Vector3.from(rightShoulder!);
    final shoulderMidpoint =
        (leftShoulderPoint + rightShoulderPoint).scaled(0.5);
    final hipMidpoint =
        (_Vector3.from(leftHip!) + _Vector3.from(rightHip!)).scaled(0.5);
    final up = (shoulderMidpoint - hipMidpoint).normalized;
    if (up == null) return null;

    final rawRight = rightShoulderPoint - leftShoulderPoint;
    final orthogonalRight = rawRight - up.scaled(rawRight.dot(up));
    final right = orthogonalRight.normalized;
    if (right == null) return null;

    final forward = up.cross(right).normalized;
    if (forward == null) return null;
    return _BodyRelativeFrame(right: right, up: up, forward: forward);
  }

  /// Plane-specific elevation from the anatomical down direction.
  ///
  /// Components outside the requested plane are deliberately ignored. A pure
  /// forward raise therefore yields 0° abduction, while a pure side raise
  /// yields 0° flexion. Negative directional components (adduction/extension)
  /// are clamped to zero because these rules model elevation from 0° to 180°.
  double? shoulderElevation(
    PoseLandmark? shoulder,
    PoseLandmark? elbow, {
    required _Vector3 direction,
    required double minConfidence,
  }) {
    if (shoulder == null ||
        elbow == null ||
        !shoulder.isReliable(minConfidence) ||
        !elbow.isReliable(minConfidence)) {
      return null;
    }
    final arm = (_Vector3.from(elbow) - _Vector3.from(shoulder)).normalized;
    if (arm == null) return null;
    final downComponent = -arm.dot(up);
    final directionComponent = math.max(0.0, arm.dot(direction));
    if (!downComponent.isFinite || !directionComponent.isFinite) return null;
    if (downComponent.abs() <= _Vector3.epsilon &&
        directionComponent <= _Vector3.epsilon) {
      return 0;
    }
    final radians = math.atan2(directionComponent, downComponent);
    final degrees = radians * 180 / math.pi;
    return degrees.isFinite ? degrees.clamp(0.0, 180.0) : null;
  }
}

class _Vector3 {
  const _Vector3(this.x, this.y, this.z);

  static const epsilon = 1e-9;
  final double x;
  final double y;
  final double z;

  factory _Vector3.from(PoseLandmark value) =>
      _Vector3(value.x, value.y, value.z);

  _Vector3 operator +(_Vector3 other) =>
      _Vector3(x + other.x, y + other.y, z + other.z);

  _Vector3 operator -(_Vector3 other) =>
      _Vector3(x - other.x, y - other.y, z - other.z);

  _Vector3 operator -() => _Vector3(-x, -y, -z);

  _Vector3 scaled(double factor) =>
      _Vector3(x * factor, y * factor, z * factor);

  double dot(_Vector3 other) => x * other.x + y * other.y + z * other.z;

  _Vector3 cross(_Vector3 other) => _Vector3(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );

  _Vector3? get normalized {
    final length = math.sqrt(dot(this));
    if (!length.isFinite || length <= epsilon) return null;
    return scaled(1 / length);
  }
}
