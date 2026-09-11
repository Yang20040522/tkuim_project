import 'dart:math' as math;
import 'dart:ui';

import '../../../models/custom_rehab_exercise.dart';
import '../../../models/exercise_keyframe.dart';
import '../../../models/joint_rotation.dart';
import '../../../models/joint_type.dart';
import 'custom_exercise_pose_features.dart';

class CustomExercisePoseReference {
  CustomExercisePoseReference({
    required this.keyframeId,
    required this.keyframeIndex,
    required this.features,
    required Set<CustomPoseFeatureType> activeFeatures,
  }) : activeFeatures = Set.unmodifiable(activeFeatures);

  final String keyframeId;
  final int keyframeIndex;
  final CustomPoseFeatures features;
  final Set<CustomPoseFeatureType> activeFeatures;
}

/// Builds observable 2D angular references from the same editor rig semantics
/// used by Three.js: GLB rest quaternion × local XYZ delta quaternion.
///
/// Rest transforms below were read from the shipped `editor_body.glb`. Wrist
/// direction uses the actual middle-metacarpal child. Ankle local rotations are
/// intentionally not evaluated because the current RTMPose mapping has no
/// verified foot-direction landmark contract; hip/knee motion is still covered
/// by thigh, knee-flexion and shin features.
class CustomExercisePoseReferenceBuilder {
  const CustomExercisePoseReferenceBuilder({
    this.activationThresholdDegrees = 6,
  });

  final double activationThresholdDegrees;

  List<CustomExercisePoseReference> build(CustomRehabExercise exercise) {
    final raw = <CustomPoseFeatures>[
      for (final keyframe in exercise.keyframes) _featuresFor(keyframe),
    ];
    return [
      for (var index = 0; index < exercise.keyframes.length; index++)
        CustomExercisePoseReference(
          keyframeId: exercise.keyframes[index].id,
          keyframeIndex: index,
          features: raw[index],
          activeFeatures: _activeFeatures(raw, index),
        ),
    ];
  }

  Set<CustomPoseFeatureType> _activeFeatures(
    List<CustomPoseFeatures> frames,
    int index,
  ) {
    final active = <CustomPoseFeatureType>{};
    final candidates = <int>{
      if (index > 0) index - 1,
      if (index + 1 < frames.length) index + 1,
    };
    for (final type in frames[index].values.keys) {
      final current = frames[index][type]!;
      for (final neighbor in candidates) {
        final other = frames[neighbor][type];
        if (other != null &&
            CustomPoseFeatureExtractor.angularError(type, current, other) >=
                activationThresholdDegrees) {
          active.add(type);
          break;
        }
      }
    }
    if (active.isNotEmpty) return active;
    return frames[index].values.keys.toSet();
  }

  CustomPoseFeatures _featuresFor(ExerciseKeyframe keyframe) {
    final leftArm = _armPose(keyframe, left: true);
    final rightArm = _armPose(keyframe, left: false);
    final leftLeg = _legPose(keyframe, left: true);
    final rightLeg = _legPose(keyframe, left: false);
    Offset projected(_Vector3 value) => Offset(value.x, -value.y);

    return const CustomPoseFeatureExtractor().fromPoints(
      leftShoulder: projected(leftArm.shoulder),
      rightShoulder: projected(rightArm.shoulder),
      leftElbow: projected(leftArm.elbow),
      rightElbow: projected(rightArm.elbow),
      leftWrist: projected(leftArm.wrist),
      rightWrist: projected(rightArm.wrist),
      leftHip: projected(leftLeg.hip),
      rightHip: projected(rightLeg.hip),
      leftKnee: projected(leftLeg.knee),
      rightKnee: projected(rightLeg.knee),
      leftAnkle: projected(leftLeg.ankle),
      rightAnkle: projected(rightLeg.ankle),
      leftPreciseWrist: projected(leftArm.wrist),
      leftHandDirectionPoint: projected(leftArm.middleMetacarpal),
      rightPreciseWrist: projected(rightArm.wrist),
      rightHandDirectionPoint: projected(rightArm.middleMetacarpal),
    );
  }

  _ArmPose _armPose(ExerciseKeyframe frame, {required bool left}) {
    final data = left ? _Rig.leftArm : _Rig.rightArm;
    final shoulderDelta =
        _delta(frame, left ? JointType.leftShoulder : JointType.rightShoulder);
    final elbowDelta =
        _delta(frame, left ? JointType.leftElbow : JointType.rightElbow);
    final wristDelta =
        _delta(frame, left ? JointType.leftWrist : JointType.rightWrist);

    final upperWorld =
        data.parentWorldQuaternion * data.upperRestQuaternion * shoulderDelta;
    final elbow = data.shoulder + upperWorld.rotate(data.lowerTranslation);
    final lowerWorld = upperWorld * data.lowerRestQuaternion * elbowDelta;
    final wrist = elbow + lowerWorld.rotate(data.handTranslation);
    final handWorld = lowerWorld * data.handRestQuaternion * wristDelta;
    final middle = wrist + handWorld.rotate(data.middleTranslation);
    return _ArmPose(
      shoulder: data.shoulder,
      elbow: elbow,
      wrist: wrist,
      middleMetacarpal: middle,
    );
  }

  _LegPose _legPose(ExerciseKeyframe frame, {required bool left}) {
    final data = left ? _Rig.leftLeg : _Rig.rightLeg;
    final hipDelta =
        _delta(frame, left ? JointType.leftHip : JointType.rightHip);
    final kneeDelta =
        _delta(frame, left ? JointType.leftKnee : JointType.rightKnee);
    final thighWorld =
        data.parentWorldQuaternion * data.thighRestQuaternion * hipDelta;
    final knee = data.hip + thighWorld.rotate(data.calfTranslation);
    final calfWorld = thighWorld * data.calfRestQuaternion * kneeDelta;
    final ankle = knee + calfWorld.rotate(data.footTranslation);
    return _LegPose(hip: data.hip, knee: knee, ankle: ankle);
  }

  _Quaternion _delta(ExerciseKeyframe frame, JointType joint) {
    final rotation = frame.jointRotations[joint] ?? JointRotation.zero;
    return _Quaternion.fromEulerXyzDegrees(rotation);
  }
}

class _ArmPose {
  const _ArmPose({
    required this.shoulder,
    required this.elbow,
    required this.wrist,
    required this.middleMetacarpal,
  });

  final _Vector3 shoulder;
  final _Vector3 elbow;
  final _Vector3 wrist;
  final _Vector3 middleMetacarpal;
}

class _LegPose {
  const _LegPose({
    required this.hip,
    required this.knee,
    required this.ankle,
  });

  final _Vector3 hip;
  final _Vector3 knee;
  final _Vector3 ankle;
}

class _ArmRig {
  const _ArmRig({
    required this.shoulder,
    required this.parentWorldQuaternion,
    required this.upperRestQuaternion,
    required this.lowerTranslation,
    required this.lowerRestQuaternion,
    required this.handTranslation,
    required this.handRestQuaternion,
    required this.middleTranslation,
  });

  final _Vector3 shoulder;
  final _Quaternion parentWorldQuaternion;
  final _Quaternion upperRestQuaternion;
  final _Vector3 lowerTranslation;
  final _Quaternion lowerRestQuaternion;
  final _Vector3 handTranslation;
  final _Quaternion handRestQuaternion;
  final _Vector3 middleTranslation;
}

class _LegRig {
  const _LegRig({
    required this.hip,
    required this.parentWorldQuaternion,
    required this.thighRestQuaternion,
    required this.calfTranslation,
    required this.calfRestQuaternion,
    required this.footTranslation,
  });

  final _Vector3 hip;
  final _Quaternion parentWorldQuaternion;
  final _Quaternion thighRestQuaternion;
  final _Vector3 calfTranslation;
  final _Quaternion calfRestQuaternion;
  final _Vector3 footTranslation;
}

class _Rig {
  static const leftArm = _ArmRig(
    shoulder: _Vector3(0.1797991801, 1.3856297151, -0.0242046457),
    parentWorldQuaternion:
        _Quaternion(-0.7065974195, 0.0667648394, -0.0347581353, 0.7036009036),
    upperRestQuaternion:
        _Quaternion(-0.0338232033, 0.3958400786, -0.0200623665, 0.9174770117),
    lowerTranslation: _Vector3(0.2697279155, 0, 0),
    lowerRestQuaternion:
        _Quaternion(-0.0000000232, 0.0000000239, -0.3315854669, 0.9434251785),
    handTranslation: _Vector3(0.2520174980, 0, 0),
    handRestQuaternion:
        _Quaternion(-0.4555024505, 0.0265141986, 0.0193994511, 0.8896281123),
    middleTranslation: _Vector3(0.0329745077, -0.0028784180, -0.0006557464),
  );

  static const rightArm = _ArmRig(
    shoulder: _Vector3(-0.1797988818, 1.3856296978, -0.0242045668),
    parentWorldQuaternion:
        _Quaternion(0.7036009722, 0.0347581748, 0.0667646877, 0.7065973744),
    upperRestQuaternion:
        _Quaternion(-0.0338232107, 0.3958400786, -0.0200623572, 0.9174770713),
    lowerTranslation: _Vector3(-0.2697300017, -0.0000002193, 0.0000008392),
    lowerRestQuaternion:
        _Quaternion(0.0000000372, -0.0000000289, -0.3315854669, 0.9434251785),
    handTranslation: _Vector3(-0.2520166337, 0.0000015640, -0.0000006866),
    handRestQuaternion:
        _Quaternion(-0.4555024803, 0.0265142322, 0.0193994530, 0.8896281123),
    middleTranslation: _Vector3(-0.0329741836, 0.0028785705, 0.0006558991),
  );

  static const leftLeg = _LegRig(
    hip: _Vector3(0.0927697718, 0.9099677305, 0.0240151358),
    parentWorldQuaternion:
        _Quaternion(-0.4762841229, -0.5226407427, 0.4762841413, 0.5226408454),
    thighRestQuaternion:
        _Quaternion(0.0716523081, -0.0259466115, 0.0493372828, 0.9958707690),
    calfTranslation: _Vector3(-0.4119220674, -0.0000000048, -0.0000000191),
    calfRestQuaternion:
        _Quaternion(0.0000000117, 0.0000000013, -0.0439935848, 0.9990318418),
    footTranslation: _Vector3(-0.4018466175, -0.0000000012, 0),
  );

  static const rightLeg = _LegRig(
    hip: _Vector3(-0.0927697994, 0.9099679785, 0.0240151328),
    parentWorldQuaternion:
        _Quaternion(-0.4762841229, -0.5226407427, 0.4762841413, 0.5226408454),
    thighRestQuaternion:
        _Quaternion(0.0259466078, 0.0716523081, 0.9958707690, -0.0493373461),
    calfTranslation: _Vector3(0.4119223952, -0.0000000095, 0.0000000286),
    calfRestQuaternion:
        _Quaternion(0.0000000040, 0.0000000017, -0.0439935736, 0.9990318418),
    footTranslation: _Vector3(0.4018464684, 0.0000000101, -0.0000002384),
  );
}

class _Vector3 {
  const _Vector3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  _Vector3 operator +(_Vector3 other) =>
      _Vector3(x + other.x, y + other.y, z + other.z);
}

class _Quaternion {
  const _Quaternion(this.x, this.y, this.z, this.w);

  final double x;
  final double y;
  final double z;
  final double w;

  factory _Quaternion.fromEulerXyzDegrees(JointRotation rotation) {
    final halfX = rotation.x * math.pi / 360;
    final halfY = rotation.y * math.pi / 360;
    final halfZ = rotation.z * math.pi / 360;
    final c1 = math.cos(halfX), s1 = math.sin(halfX);
    final c2 = math.cos(halfY), s2 = math.sin(halfY);
    final c3 = math.cos(halfZ), s3 = math.sin(halfZ);
    return _Quaternion(
      s1 * c2 * c3 + c1 * s2 * s3,
      c1 * s2 * c3 - s1 * c2 * s3,
      c1 * c2 * s3 + s1 * s2 * c3,
      c1 * c2 * c3 - s1 * s2 * s3,
    );
  }

  _Quaternion operator *(_Quaternion other) => _Quaternion(
        w * other.x + x * other.w + y * other.z - z * other.y,
        w * other.y - x * other.z + y * other.w + z * other.x,
        w * other.z + x * other.y - y * other.x + z * other.w,
        w * other.w - x * other.x - y * other.y - z * other.z,
      );

  _Vector3 rotate(_Vector3 vector) {
    final tx = 2 * (y * vector.z - z * vector.y);
    final ty = 2 * (z * vector.x - x * vector.z);
    final tz = 2 * (x * vector.y - y * vector.x);
    return _Vector3(
      vector.x + w * tx + y * tz - z * ty,
      vector.y + w * ty + z * tx - x * tz,
      vector.z + w * tz + x * ty - y * tx,
    );
  }
}
