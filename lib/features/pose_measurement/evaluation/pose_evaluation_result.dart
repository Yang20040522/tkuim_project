import 'pose_measurement_rule.dart';

enum PoseRuleEvaluationStatus { pass, tooLow, tooHigh, unavailable }

enum PoseOverallEvaluationStatus {
  correct,
  needsAdjustment,
  unavailable,
  noRules,
}

class PoseRuleEvaluationResult {
  const PoseRuleEvaluationResult({
    required this.rule,
    required this.currentAngleDegrees,
    required this.status,
    required this.feedback,
  });

  final PoseMeasurementRule rule;
  final double? currentAngleDegrees;
  final PoseRuleEvaluationStatus status;
  final String feedback;

  double get lowerBound => rule.lowerBound;
  double get upperBound => rule.upperBound;
}

class PoseEvaluationResult {
  const PoseEvaluationResult({
    required this.rules,
    required this.overallStatus,
  });

  final List<PoseRuleEvaluationResult> rules;
  final PoseOverallEvaluationStatus overallStatus;
}

class StabilizedPoseEvaluation {
  const StabilizedPoseEvaluation({
    required this.raw,
    required this.presentedOverallStatus,
  });

  final PoseEvaluationResult raw;
  final PoseOverallEvaluationStatus presentedOverallStatus;
}
