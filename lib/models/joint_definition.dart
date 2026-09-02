import 'joint_rotation.dart';
import 'joint_type.dart';

class RotationRange {
  final double min;
  final double max;

  const RotationRange({required this.min, required this.max})
      : assert(min <= max);
}

class JointDefinition {
  final JointType type;
  final String displayName;
  final RotationRange xRange;
  final RotationRange yRange;
  final RotationRange zRange;
  final JointRotation defaultRotation;

  const JointDefinition({
    required this.type,
    required this.displayName,
    this.xRange = const RotationRange(min: -180, max: 180),
    this.yRange = const RotationRange(min: -180, max: 180),
    this.zRange = const RotationRange(min: -180, max: 180),
    this.defaultRotation = JointRotation.zero,
  });
}

class JointDefinitions {
  JointDefinitions._();

  static const List<JointDefinition> all = [
    JointDefinition(type: JointType.leftShoulder, displayName: '左肩'),
    JointDefinition(type: JointType.rightShoulder, displayName: '右肩'),
    JointDefinition(type: JointType.leftElbow, displayName: '左肘'),
    JointDefinition(type: JointType.rightElbow, displayName: '右肘'),
    JointDefinition(type: JointType.leftWrist, displayName: '左腕'),
    JointDefinition(type: JointType.rightWrist, displayName: '右腕'),
    JointDefinition(type: JointType.leftHip, displayName: '左髖'),
    JointDefinition(type: JointType.rightHip, displayName: '右髖'),
    JointDefinition(type: JointType.leftKnee, displayName: '左膝'),
    JointDefinition(type: JointType.rightKnee, displayName: '右膝'),
    JointDefinition(type: JointType.leftAnkle, displayName: '左踝'),
    JointDefinition(type: JointType.rightAnkle, displayName: '右踝'),
  ];

  static JointDefinition of(JointType type) =>
      all.firstWhere((definition) => definition.type == type);
}

class DefaultPose {
  DefaultPose._();

  static final Map<JointType, JointRotation> rotations =
      Map.unmodifiable({
    for (final definition in JointDefinitions.all)
      definition.type: definition.defaultRotation,
  });

  static JointRotation rotationOf(JointType type) =>
      rotations[type] ?? JointRotation.zero;
}
