enum JointType {
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
}

extension JointTypeJson on JointType {
  static JointType fromJson(String value) {
    return JointType.values.firstWhere(
      (joint) => joint.name == value,
      orElse: () => throw FormatException('未知的關節類型: $value'),
    );
  }
}
