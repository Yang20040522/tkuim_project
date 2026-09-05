import '../models/joint_angle_frame.dart';
import 'pose_evaluation_result.dart';
import 'pose_measurement_rule.dart';

/// Stateless target ± tolerance evaluation over already validated world angles.
class PoseEvaluationEngine {
  const PoseEvaluationEngine();

  PoseEvaluationResult evaluate({
    required JointAngleFrame measurements,
    required List<PoseMeasurementRule> rules,
  }) {
    if (rules.isEmpty) {
      return const PoseEvaluationResult(
        rules: [],
        overallStatus: PoseOverallEvaluationStatus.noRules,
      );
    }

    final results = <PoseRuleEvaluationResult>[];
    for (final rule in rules) {
      final current = measurements[rule.measurement];
      results.add(_evaluateRule(rule, current));
    }

    final hasFailure = results.any((result) =>
        result.status == PoseRuleEvaluationStatus.tooLow ||
        result.status == PoseRuleEvaluationStatus.tooHigh);
    final hasUnavailable = results.any(
      (result) => result.status == PoseRuleEvaluationStatus.unavailable,
    );
    final overall = hasFailure
        ? PoseOverallEvaluationStatus.needsAdjustment
        : hasUnavailable
            ? PoseOverallEvaluationStatus.unavailable
            : PoseOverallEvaluationStatus.correct;
    return PoseEvaluationResult(
      rules: List.unmodifiable(results),
      overallStatus: overall,
    );
  }

  PoseRuleEvaluationResult _evaluateRule(
    PoseMeasurementRule rule,
    double? current,
  ) {
    if (!rule.isValid ||
        current == null ||
        !current.isFinite ||
        current < 0 ||
        current > 180) {
      return PoseRuleEvaluationResult(
        rule: rule,
        currentAngleDegrees: null,
        status: PoseRuleEvaluationStatus.unavailable,
        feedback: '目前無法可靠判定此關節',
      );
    }
    if (current < rule.lowerBound) {
      return PoseRuleEvaluationResult(
        rule: rule,
        currentAngleDegrees: current,
        status: PoseRuleEvaluationStatus.tooLow,
        feedback:
            rule.feedbackTooLow ?? '請增加${rule.measurement.evaluationLabel}角度',
      );
    }
    if (current > rule.upperBound) {
      return PoseRuleEvaluationResult(
        rule: rule,
        currentAngleDegrees: current,
        status: PoseRuleEvaluationStatus.tooHigh,
        feedback:
            rule.feedbackTooHigh ?? '請減少${rule.measurement.evaluationLabel}角度',
      );
    }
    return PoseRuleEvaluationResult(
      rule: rule,
      currentAngleDegrees: current,
      status: PoseRuleEvaluationStatus.pass,
      feedback: '角度正確',
    );
  }
}

extension JointMeasurementEvaluationLabel on JointMeasurementType {
  String get evaluationLabel => switch (this) {
        JointMeasurementType.leftElbow => '左手肘',
        JointMeasurementType.rightElbow => '右手肘',
        JointMeasurementType.leftKnee => '左膝',
        JointMeasurementType.rightKnee => '右膝',
        JointMeasurementType.leftShoulderBodyAngle => '左肩軀幹',
        JointMeasurementType.rightShoulderBodyAngle => '右肩軀幹',
        JointMeasurementType.leftHipBodyAngle => '左髖軀幹',
        JointMeasurementType.rightHipBodyAngle => '右髖軀幹',
      };
}
