import '../models/joint_angle_frame.dart';

/// A rule for a real person's world-landmark geometric angle.
///
/// This deliberately has no [JointType] or GLB X/Y/Z axis: editor bone-local
/// rotations and anatomical three-point measurements are different semantics.
class PoseMeasurementRule {
  const PoseMeasurementRule({
    required this.measurement,
    required this.targetAngleDegrees,
    required this.toleranceDegrees,
    this.feedbackTooLow,
    this.feedbackTooHigh,
  });

  final JointMeasurementType measurement;
  final double targetAngleDegrees;
  final double toleranceDegrees;
  final String? feedbackTooLow;
  final String? feedbackTooHigh;

  static const supportedCustomMeasurements = <JointMeasurementType>[
    JointMeasurementType.leftElbow,
    JointMeasurementType.rightElbow,
    JointMeasurementType.leftKnee,
    JointMeasurementType.rightKnee,
    JointMeasurementType.leftShoulderAbduction,
    JointMeasurementType.rightShoulderAbduction,
    JointMeasurementType.leftShoulderFlexion,
    JointMeasurementType.rightShoulderFlexion,
  ];

  bool get isValid =>
      targetAngleDegrees.isFinite &&
      targetAngleDegrees >= 0 &&
      targetAngleDegrees <= 180 &&
      toleranceDegrees.isFinite &&
      toleranceDegrees > 0 &&
      lowerBound >= 0 &&
      upperBound <= 180;

  double get lowerBound => targetAngleDegrees - toleranceDegrees;
  double get upperBound => targetAngleDegrees + toleranceDegrees;

  String? get validationError {
    if (!targetAngleDegrees.isFinite ||
        targetAngleDegrees < 0 ||
        targetAngleDegrees > 180) {
      return '目標角度必須介於 0°～180°';
    }
    if (!toleranceDegrees.isFinite || toleranceDegrees <= 0) {
      return '容許誤差必須大於 0°';
    }
    if (lowerBound < 0 || upperBound > 180) {
      return '設定後的角度範圍不可超出 0°～180°';
    }
    if (!supportedCustomMeasurements.contains(measurement)) {
      return '此人體關節角度目前尚未支援';
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'measurement': measurement.apiValue,
        'targetAngleDegrees': targetAngleDegrees,
        'toleranceDegrees': toleranceDegrees,
        if (feedbackTooLow != null) 'feedbackTooLow': feedbackTooLow,
        if (feedbackTooHigh != null) 'feedbackTooHigh': feedbackTooHigh,
      };

  factory PoseMeasurementRule.fromJson(Map<String, dynamic> json) {
    final measurement = JointMeasurementTypePoseRuleJson.fromPoseRuleJson(
      json['measurement'],
    );
    final target = _finiteDouble(
      json['targetAngleDegrees'],
      field: 'targetAngleDegrees',
    );
    final tolerance = _finiteDouble(
      json['toleranceDegrees'],
      field: 'toleranceDegrees',
    );
    final low = json['feedbackTooLow'];
    final high = json['feedbackTooHigh'];
    if (low != null && low is! String || high != null && high is! String) {
      throw const FormatException('姿勢提示文字格式錯誤');
    }
    final rule = PoseMeasurementRule(
      measurement: measurement,
      targetAngleDegrees: target,
      toleranceDegrees: tolerance,
      feedbackTooLow: (low as String?)?.trim().isEmpty == true ? null : low,
      feedbackTooHigh: (high as String?)?.trim().isEmpty == true ? null : high,
    );
    final error = rule.validationError;
    if (error != null) throw FormatException(error);
    return rule;
  }

  static PoseMeasurementRule? tryFromJson(Object? value) {
    try {
      if (value is! Map) return null;
      return PoseMeasurementRule.fromJson(Map<String, dynamic>.from(value));
    } on Object {
      return null;
    }
  }

  static double _finiteDouble(Object? value, {required String field}) {
    final number = value is num ? value.toDouble() : null;
    if (number == null || !number.isFinite) {
      throw FormatException('$field 必須是有限數值');
    }
    return number;
  }
}

extension JointMeasurementTypePoseRuleJson on JointMeasurementType {
  String get poseRuleLabel => switch (this) {
        JointMeasurementType.leftElbow => '左手肘角度',
        JointMeasurementType.rightElbow => '右手肘角度',
        JointMeasurementType.leftKnee => '左膝角度',
        JointMeasurementType.rightKnee => '右膝角度',
        JointMeasurementType.leftShoulderAbduction => '左肩側抬',
        JointMeasurementType.rightShoulderAbduction => '右肩側抬',
        JointMeasurementType.leftShoulderFlexion => '左肩前抬',
        JointMeasurementType.rightShoulderFlexion => '右肩前抬',
        _ => label,
      };

  String get apiValue => switch (this) {
        JointMeasurementType.leftElbow => 'LEFT_ELBOW_ANGLE',
        JointMeasurementType.rightElbow => 'RIGHT_ELBOW_ANGLE',
        JointMeasurementType.leftKnee => 'LEFT_KNEE_ANGLE',
        JointMeasurementType.rightKnee => 'RIGHT_KNEE_ANGLE',
        JointMeasurementType.leftShoulderAbduction => 'LEFT_SHOULDER_ABDUCTION',
        JointMeasurementType.rightShoulderAbduction =>
          'RIGHT_SHOULDER_ABDUCTION',
        JointMeasurementType.leftShoulderFlexion => 'LEFT_SHOULDER_FLEXION',
        JointMeasurementType.rightShoulderFlexion => 'RIGHT_SHOULDER_FLEXION',
        _ => throw UnsupportedError('此量測類型尚未開放自訂規則'),
      };

  static JointMeasurementType fromPoseRuleJson(Object? value) {
    return switch (value) {
      'LEFT_ELBOW_ANGLE' => JointMeasurementType.leftElbow,
      'RIGHT_ELBOW_ANGLE' => JointMeasurementType.rightElbow,
      'LEFT_KNEE_ANGLE' => JointMeasurementType.leftKnee,
      'RIGHT_KNEE_ANGLE' => JointMeasurementType.rightKnee,
      'LEFT_SHOULDER_ABDUCTION' => JointMeasurementType.leftShoulderAbduction,
      'RIGHT_SHOULDER_ABDUCTION' => JointMeasurementType.rightShoulderAbduction,
      'LEFT_SHOULDER_FLEXION' => JointMeasurementType.leftShoulderFlexion,
      'RIGHT_SHOULDER_FLEXION' => JointMeasurementType.rightShoulderFlexion,
      _ => throw FormatException('不支援的人體關節角度：$value'),
    };
  }
}
