import 'dart:math' as math;
import 'dart:ui';

import '../../../models/joint_type.dart';
import '../../../models/pose_data.dart';

enum CustomPoseFeatureType {
  leftUpperArmDirection,
  rightUpperArmDirection,
  leftElbowFlexion,
  rightElbowFlexion,
  leftForearmDirection,
  rightForearmDirection,
  leftWristDirection,
  rightWristDirection,
  leftThighDirection,
  rightThighDirection,
  leftKneeFlexion,
  rightKneeFlexion,
  leftShinDirection,
  rightShinDirection,
}

extension CustomPoseFeatureTypeInfo on CustomPoseFeatureType {
  bool get isCircular => switch (this) {
        CustomPoseFeatureType.leftElbowFlexion ||
        CustomPoseFeatureType.rightElbowFlexion ||
        CustomPoseFeatureType.leftKneeFlexion ||
        CustomPoseFeatureType.rightKneeFlexion =>
          false,
        _ => true,
      };

  double get toleranceDegrees => switch (this) {
        CustomPoseFeatureType.leftElbowFlexion ||
        CustomPoseFeatureType.rightElbowFlexion ||
        CustomPoseFeatureType.leftKneeFlexion ||
        CustomPoseFeatureType.rightKneeFlexion =>
          20,
        CustomPoseFeatureType.leftWristDirection ||
        CustomPoseFeatureType.rightWristDirection =>
          28,
        _ => 24,
      };

  JointType get joint => switch (this) {
        CustomPoseFeatureType.leftUpperArmDirection => JointType.leftShoulder,
        CustomPoseFeatureType.rightUpperArmDirection => JointType.rightShoulder,
        CustomPoseFeatureType.leftElbowFlexion ||
        CustomPoseFeatureType.leftForearmDirection =>
          JointType.leftElbow,
        CustomPoseFeatureType.rightElbowFlexion ||
        CustomPoseFeatureType.rightForearmDirection =>
          JointType.rightElbow,
        CustomPoseFeatureType.leftWristDirection => JointType.leftWrist,
        CustomPoseFeatureType.rightWristDirection => JointType.rightWrist,
        CustomPoseFeatureType.leftThighDirection => JointType.leftHip,
        CustomPoseFeatureType.rightThighDirection => JointType.rightHip,
        CustomPoseFeatureType.leftKneeFlexion ||
        CustomPoseFeatureType.leftShinDirection =>
          JointType.leftKnee,
        CustomPoseFeatureType.rightKneeFlexion ||
        CustomPoseFeatureType.rightShinDirection =>
          JointType.rightKnee,
      };

  String get label => switch (this) {
        CustomPoseFeatureType.leftUpperArmDirection => '左上臂方向',
        CustomPoseFeatureType.rightUpperArmDirection => '右上臂方向',
        CustomPoseFeatureType.leftElbowFlexion => '左手肘彎曲',
        CustomPoseFeatureType.rightElbowFlexion => '右手肘彎曲',
        CustomPoseFeatureType.leftForearmDirection => '左前臂方向',
        CustomPoseFeatureType.rightForearmDirection => '右前臂方向',
        CustomPoseFeatureType.leftWristDirection => '左手腕方向',
        CustomPoseFeatureType.rightWristDirection => '右手腕方向',
        CustomPoseFeatureType.leftThighDirection => '左大腿方向',
        CustomPoseFeatureType.rightThighDirection => '右大腿方向',
        CustomPoseFeatureType.leftKneeFlexion => '左膝彎曲',
        CustomPoseFeatureType.rightKneeFlexion => '右膝彎曲',
        CustomPoseFeatureType.leftShinDirection => '左小腿方向',
        CustomPoseFeatureType.rightShinDirection => '右小腿方向',
      };
}

class CustomPoseFeatures {
  CustomPoseFeatures({
    required Map<CustomPoseFeatureType, double> values,
    Set<JointType> unavailableJoints = const {},
  })  : values = Map.unmodifiable(values),
        unavailableJoints = Set.unmodifiable(unavailableJoints);

  final Map<CustomPoseFeatureType, double> values;
  final Set<JointType> unavailableJoints;

  double? operator [](CustomPoseFeatureType type) => values[type];
}

/// Converts both GLB-derived reference points and RTMPose landmarks into the
/// same camera-independent angular representation.
///
/// The anatomical lateral axis is derived from RIGHT shoulder to LEFT
/// shoulder. This makes mirror handling invariant: preview coordinates may be
/// mirrored, but RTMPose landmark identities are never swapped here.
class CustomPoseFeatureExtractor {
  const CustomPoseFeatureExtractor({this.confidenceThreshold = 0.3});

  final double confidenceThreshold;

  static const _leftShoulder = 5;
  static const _rightShoulder = 6;
  static const _leftElbow = 7;
  static const _rightElbow = 8;
  static const _leftWrist = 9;
  static const _rightWrist = 10;
  static const _leftHip = 11;
  static const _rightHip = 12;
  static const _leftKnee = 13;
  static const _rightKnee = 14;
  static const _leftAnkle = 15;
  static const _rightAnkle = 16;
  static const _leftPreciseWrist = 91;
  static const _leftMiddleBase = 100;
  static const _rightPreciseWrist = 112;
  static const _rightMiddleBase = 121;

  CustomPoseFeatures fromPoseData(PoseData data) {
    final unavailable = <JointType>{};
    Offset? point(int index, JointType joint) {
      if (index >= data.keypoints.length || index >= data.scores.length) {
        unavailable.add(joint);
        return null;
      }
      final value = data.keypoints[index];
      final score = data.scores[index];
      if (!value.dx.isFinite ||
          !value.dy.isFinite ||
          !score.isFinite ||
          score < confidenceThreshold) {
        unavailable.add(joint);
        return null;
      }
      return value;
    }

    return fromPoints(
      leftShoulder: point(_leftShoulder, JointType.leftShoulder),
      rightShoulder: point(_rightShoulder, JointType.rightShoulder),
      leftElbow: point(_leftElbow, JointType.leftElbow),
      rightElbow: point(_rightElbow, JointType.rightElbow),
      leftWrist: point(_leftWrist, JointType.leftWrist),
      rightWrist: point(_rightWrist, JointType.rightWrist),
      leftHip: point(_leftHip, JointType.leftHip),
      rightHip: point(_rightHip, JointType.rightHip),
      leftKnee: point(_leftKnee, JointType.leftKnee),
      rightKnee: point(_rightKnee, JointType.rightKnee),
      leftAnkle: point(_leftAnkle, JointType.leftAnkle),
      rightAnkle: point(_rightAnkle, JointType.rightAnkle),
      leftPreciseWrist: point(_leftPreciseWrist, JointType.leftWrist),
      leftHandDirectionPoint: point(_leftMiddleBase, JointType.leftWrist),
      rightPreciseWrist: point(_rightPreciseWrist, JointType.rightWrist),
      rightHandDirectionPoint: point(_rightMiddleBase, JointType.rightWrist),
      unavailableJoints: unavailable,
    );
  }

  CustomPoseFeatures fromPoints({
    required Offset? leftShoulder,
    required Offset? rightShoulder,
    required Offset? leftElbow,
    required Offset? rightElbow,
    required Offset? leftWrist,
    required Offset? rightWrist,
    required Offset? leftHip,
    required Offset? rightHip,
    required Offset? leftKnee,
    required Offset? rightKnee,
    required Offset? leftAnkle,
    required Offset? rightAnkle,
    Offset? leftPreciseWrist,
    Offset? leftHandDirectionPoint,
    Offset? rightPreciseWrist,
    Offset? rightHandDirectionPoint,
    Set<JointType> unavailableJoints = const {},
  }) {
    final values = <CustomPoseFeatureType, double>{};
    final frame = _BodyFrame2d.tryCreate(
      leftShoulder: leftShoulder,
      rightShoulder: rightShoulder,
      leftHip: leftHip,
      rightHip: rightHip,
    );

    void direction(
      CustomPoseFeatureType type,
      Offset? start,
      Offset? end,
    ) {
      if (frame == null || start == null || end == null) return;
      final value = frame.directionDegrees(end - start);
      if (value != null) values[type] = value;
    }

    void flexion(
      CustomPoseFeatureType type,
      Offset? parent,
      Offset? joint,
      Offset? child,
    ) {
      if (parent == null || joint == null || child == null) return;
      final value = _flexionDegrees(parent - joint, child - joint);
      if (value != null) values[type] = value;
    }

    direction(
        CustomPoseFeatureType.leftUpperArmDirection, leftShoulder, leftElbow);
    direction(CustomPoseFeatureType.rightUpperArmDirection, rightShoulder,
        rightElbow);
    flexion(CustomPoseFeatureType.leftElbowFlexion, leftShoulder, leftElbow,
        leftWrist);
    flexion(CustomPoseFeatureType.rightElbowFlexion, rightShoulder, rightElbow,
        rightWrist);
    direction(CustomPoseFeatureType.leftForearmDirection, leftElbow, leftWrist);
    direction(
        CustomPoseFeatureType.rightForearmDirection, rightElbow, rightWrist);
    direction(CustomPoseFeatureType.leftWristDirection, leftPreciseWrist,
        leftHandDirectionPoint);
    direction(CustomPoseFeatureType.rightWristDirection, rightPreciseWrist,
        rightHandDirectionPoint);
    direction(CustomPoseFeatureType.leftThighDirection, leftHip, leftKnee);
    direction(CustomPoseFeatureType.rightThighDirection, rightHip, rightKnee);
    flexion(
        CustomPoseFeatureType.leftKneeFlexion, leftHip, leftKnee, leftAnkle);
    flexion(CustomPoseFeatureType.rightKneeFlexion, rightHip, rightKnee,
        rightAnkle);
    direction(CustomPoseFeatureType.leftShinDirection, leftKnee, leftAnkle);
    direction(CustomPoseFeatureType.rightShinDirection, rightKnee, rightAnkle);

    return CustomPoseFeatures(
      values: values,
      unavailableJoints: unavailableJoints,
    );
  }

  static double angularError(
    CustomPoseFeatureType type,
    double a,
    double b,
  ) {
    final raw = (a - b).abs();
    return type.isCircular ? math.min(raw, 360 - raw) : raw;
  }

  static double? _flexionDegrees(Offset first, Offset second) {
    final firstLength = first.distance;
    final secondLength = second.distance;
    if (firstLength < 1e-6 || secondLength < 1e-6) return null;
    final cosine = ((first.dx * second.dx + first.dy * second.dy) /
            (firstLength * secondLength))
        .clamp(-1.0, 1.0);
    final internalAngle = math.acos(cosine) * 180 / math.pi;
    final flexion = 180 - internalAngle;
    return flexion.isFinite ? flexion.clamp(0.0, 180.0) : null;
  }
}

class _BodyFrame2d {
  const _BodyFrame2d({required this.up, required this.left});

  final Offset up;
  final Offset left;

  static _BodyFrame2d? tryCreate({
    required Offset? leftShoulder,
    required Offset? rightShoulder,
    required Offset? leftHip,
    required Offset? rightHip,
  }) {
    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null) {
      return null;
    }
    final shoulderCenter = (leftShoulder + rightShoulder) / 2;
    final hipCenter = (leftHip + rightHip) / 2;
    final up = _normalize(shoulderCenter - hipCenter);
    if (up == null) return null;

    final rawLeft = leftShoulder - rightShoulder;
    final projection = rawLeft.dx * up.dx + rawLeft.dy * up.dy;
    final orthogonalLeft = rawLeft - up * projection;
    final left = _normalize(orthogonalLeft);
    if (left == null) return null;
    return _BodyFrame2d(up: up, left: left);
  }

  double? directionDegrees(Offset vector) {
    final normalized = _normalize(vector);
    if (normalized == null) return null;
    final upComponent = normalized.dx * up.dx + normalized.dy * up.dy;
    final leftComponent = normalized.dx * left.dx + normalized.dy * left.dy;
    final value = math.atan2(leftComponent, upComponent) * 180 / math.pi;
    return value.isFinite ? value : null;
  }

  static Offset? _normalize(Offset value) {
    final length = value.distance;
    if (!length.isFinite || length < 1e-6) return null;
    return value / length;
  }
}
