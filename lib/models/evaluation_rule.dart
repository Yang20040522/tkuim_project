import 'joint_type.dart';

enum RotationAxis { x, y, z }

class EvaluationRule {
  final JointType joint;
  final RotationAxis axis;
  final double targetAngle;
  final double tolerance;
  final String? instructionTooLow;
  final String? instructionTooHigh;

  const EvaluationRule({
    required this.joint,
    required this.axis,
    required this.targetAngle,
    required this.tolerance,
    this.instructionTooLow,
    this.instructionTooHigh,
  })  : assert(targetAngle >= -double.maxFinite &&
            targetAngle <= double.maxFinite),
        assert(tolerance >= 0 && tolerance <= double.maxFinite);

  bool passes(double measuredAngle) {
    if (!measuredAngle.isFinite) return false;
    return (measuredAngle - targetAngle).abs() <= tolerance;
  }

  EvaluationRule copyWith({
    JointType? joint,
    RotationAxis? axis,
    double? targetAngle,
    double? tolerance,
    String? instructionTooLow,
    String? instructionTooHigh,
    bool clearInstructionTooLow = false,
    bool clearInstructionTooHigh = false,
  }) {
    return EvaluationRule(
      joint: joint ?? this.joint,
      axis: axis ?? this.axis,
      targetAngle: targetAngle ?? this.targetAngle,
      tolerance: tolerance ?? this.tolerance,
      instructionTooLow:
          clearInstructionTooLow ? null : instructionTooLow ?? this.instructionTooLow,
      instructionTooHigh: clearInstructionTooHigh
          ? null
          : instructionTooHigh ?? this.instructionTooHigh,
    );
  }

  Map<String, dynamic> toJson() => {
        'joint': joint.name,
        'axis': axis.name,
        'targetAngle': targetAngle,
        'tolerance': tolerance,
        if (instructionTooLow != null) 'instructionTooLow': instructionTooLow,
        if (instructionTooHigh != null) 'instructionTooHigh': instructionTooHigh,
      };

  factory EvaluationRule.fromJson(Map<String, dynamic> json) {
    final jointValue = json['joint'];
    final axisValue = json['axis'];
    final targetValue = json['targetAngle'];
    final toleranceValue = json['tolerance'];
    final target = targetValue is num ? targetValue.toDouble() : double.nan;
    final tolerance =
        toleranceValue is num ? toleranceValue.toDouble() : double.nan;
    if (jointValue is! String || axisValue is! String) {
      throw const FormatException('EvaluationRule 關節或軸向格式錯誤');
    }
    if (!target.isFinite || !tolerance.isFinite || tolerance < 0) {
      throw const FormatException('EvaluationRule 數值無效');
    }
    final axis = RotationAxis.values.firstWhere(
      (value) => value.name == axisValue,
      orElse: () => throw FormatException('未知的旋轉軸: $axisValue'),
    );
    return EvaluationRule(
      joint: JointTypeJson.fromJson(jointValue),
      axis: axis,
      targetAngle: target,
      tolerance: tolerance,
      instructionTooLow: json['instructionTooLow'] as String?,
      instructionTooHigh: json['instructionTooHigh'] as String?,
    );
  }
}
