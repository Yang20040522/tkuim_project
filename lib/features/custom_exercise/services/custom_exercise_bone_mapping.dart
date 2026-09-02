import '../../../models/joint_type.dart';

/// Editor 專用的語意關節與實際 GLB bone name 對照。
///
/// 名稱來自專用 `editor_body.glb` 的 351 個 runtime bones。
class CustomExerciseBoneMapping {
  CustomExerciseBoneMapping._();

  static const Map<JointType, String> verifiedBoneNames = {
    JointType.leftShoulder: 'DHIbody:upperarm_l',
    JointType.rightShoulder: 'DHIbody:upperarm_r',
    JointType.leftElbow: 'DHIbody:lowerarm_l',
    JointType.rightElbow: 'DHIbody:lowerarm_r',
    JointType.leftWrist: 'DHIbody:hand_l',
    JointType.rightWrist: 'DHIbody:hand_r',
    JointType.leftHip: 'DHIbody:thigh_l',
    JointType.rightHip: 'DHIbody:thigh_r',
    JointType.leftKnee: 'DHIbody:calf_l',
    JointType.rightKnee: 'DHIbody:calf_r',
    JointType.leftAnkle: 'DHIbody:foot_l',
    JointType.rightAnkle: 'DHIbody:foot_r',
  };

  /// Milestone 3B 第二批開放完整 12 個主要關節。
  static const List<JointType> controllableJoints = [
    JointType.leftShoulder,
    JointType.rightShoulder,
    JointType.leftElbow,
    JointType.rightElbow,
    JointType.leftWrist,
    JointType.rightWrist,
    JointType.leftHip,
    JointType.rightHip,
    JointType.leftKnee,
    JointType.rightKnee,
    JointType.leftAnkle,
    JointType.rightAnkle,
  ];

  static String boneNameFor(JointType joint) {
    final name = verifiedBoneNames[joint];
    if (name == null) {
      throw UnsupportedError('${joint.name} 尚未完成 GLB bone mapping');
    }
    return name;
  }
}
