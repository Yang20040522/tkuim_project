enum JointMeasurementType {
  leftElbow('左肘角'),
  rightElbow('右肘角'),
  leftKnee('左膝角'),
  rightKnee('右膝角'),
  leftShoulderAbduction('左肩側抬'),
  rightShoulderAbduction('右肩側抬'),
  leftShoulderFlexion('左肩前抬'),
  rightShoulderFlexion('右肩前抬'),
  leftShoulderBodyAngle('左肩軀幹角'),
  rightShoulderBodyAngle('右肩軀幹角'),
  leftHipBodyAngle('左髖軀幹角'),
  rightHipBodyAngle('右髖軀幹角');

  const JointMeasurementType(this.label);
  final String label;
}

class JointAngleFrame {
  JointAngleFrame({
    required this.timestampMs,
    required Map<JointMeasurementType, double?> angles,
  }) : angles = Map.unmodifiable(angles);

  final int timestampMs;

  /// Null means unavailable; a valid geometric zero remains distinguishable.
  final Map<JointMeasurementType, double?> angles;

  double? operator [](JointMeasurementType type) => angles[type];
}
