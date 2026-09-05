import 'package:flutter_body/features/pose_measurement/evaluation/pose_evaluation_engine.dart';
import 'package:flutter_body/features/pose_measurement/evaluation/pose_evaluation_result.dart';
import 'package:flutter_body/features/pose_measurement/evaluation/pose_measurement_rule.dart';
import 'package:flutter_body/features/pose_measurement/models/joint_angle_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const elbow = PoseMeasurementRule(
    measurement: JointMeasurementType.leftElbow,
    targetAngleDegrees: 90,
    toleranceDegrees: 10,
  );
  const rightElbow = PoseMeasurementRule(
    measurement: JointMeasurementType.rightElbow,
    targetAngleDegrees: 120,
    toleranceDegrees: 5,
  );
  const engine = PoseEvaluationEngine();

  PoseEvaluationResult evaluate(
    Map<JointMeasurementType, double?> angles, [
    List<PoseMeasurementRule> rules = const [elbow],
  ]) =>
      engine.evaluate(
        measurements: JointAngleFrame(timestampMs: 1, angles: angles),
        rules: rules,
      );

  test('exact target and inclusive tolerance boundaries pass', () {
    for (final value in [80.0, 90.0, 100.0]) {
      final result = evaluate({JointMeasurementType.leftElbow: value});
      expect(result.rules.single.status, PoseRuleEvaluationStatus.pass);
      expect(result.rules.single.feedback, '角度正確');
    }
  });

  test('outside lower and upper bounds returns corrective result', () {
    final low = evaluate({JointMeasurementType.leftElbow: 79.9}).rules.single;
    final high = evaluate({JointMeasurementType.leftElbow: 100.1}).rules.single;
    expect(low.status, PoseRuleEvaluationStatus.tooLow);
    expect(low.feedback, '請增加左手肘角度');
    expect(high.status, PoseRuleEvaluationStatus.tooHigh);
    expect(high.feedback, '請減少左手肘角度');
    expect(low.lowerBound, 80);
    expect(high.upperBound, 100);
  });

  test('custom corrective feedback has priority', () {
    const rule = PoseMeasurementRule(
      measurement: JointMeasurementType.leftKnee,
      targetAngleDegrees: 90,
      toleranceDegrees: 5,
      feedbackTooLow: '自訂偏低提示',
      feedbackTooHigh: '自訂偏高提示',
    );
    expect(
      evaluate({JointMeasurementType.leftKnee: 70}, [rule])
          .rules
          .single
          .feedback,
      '自訂偏低提示',
    );
    expect(
      evaluate({JointMeasurementType.leftKnee: 110}, [rule])
          .rules
          .single
          .feedback,
      '自訂偏高提示',
    );
  });

  test('missing and all non-finite values are unavailable', () {
    for (final value in <double?>[
      null,
      double.nan,
      double.infinity,
      double.negativeInfinity
    ]) {
      final result = evaluate({JointMeasurementType.leftElbow: value});
      expect(result.rules.single.status, PoseRuleEvaluationStatus.unavailable);
      expect(result.rules.single.currentAngleDegrees, isNull);
      expect(result.rules.single.feedback, '目前無法可靠判定此關節');
      expect(result.overallStatus, PoseOverallEvaluationStatus.unavailable);
    }
  });

  test('angles outside anatomical 0 to 180 are unavailable', () {
    expect(
      evaluate({JointMeasurementType.leftElbow: -0.1}).rules.single.status,
      PoseRuleEvaluationStatus.unavailable,
    );
    expect(
      evaluate({JointMeasurementType.leftElbow: 180.1}).rules.single.status,
      PoseRuleEvaluationStatus.unavailable,
    );
  });

  test('invalid runtime rule numbers cannot accidentally pass', () {
    const invalid = PoseMeasurementRule(
      measurement: JointMeasurementType.leftElbow,
      targetAngleDegrees: double.nan,
      toleranceDegrees: 10,
    );
    expect(
      evaluate({JointMeasurementType.leftElbow: 90}, [invalid])
          .rules.single.status,
      PoseRuleEvaluationStatus.unavailable,
    );
  });

  test('all pass, one fail, missing rule and no rules set overall status', () {
    final rules = [elbow, rightElbow];
    expect(
      evaluate({
        JointMeasurementType.leftElbow: 90,
        JointMeasurementType.rightElbow: 120,
      }, rules)
          .overallStatus,
      PoseOverallEvaluationStatus.correct,
    );
    expect(
      evaluate({
        JointMeasurementType.leftElbow: 70,
        JointMeasurementType.rightElbow: null,
      }, rules)
          .overallStatus,
      PoseOverallEvaluationStatus.needsAdjustment,
    );
    expect(
      evaluate({JointMeasurementType.leftElbow: 90}, rules).overallStatus,
      PoseOverallEvaluationStatus.unavailable,
    );
    expect(
      evaluate(const {}, const []).overallStatus,
      PoseOverallEvaluationStatus.noRules,
    );
  });

  test('left elbow never reads right elbow', () {
    final result = evaluate({JointMeasurementType.rightElbow: 90});
    expect(result.rules.single.status, PoseRuleEvaluationStatus.unavailable);
  });

  test('left knee never reads right knee', () {
    const rule = PoseMeasurementRule(
      measurement: JointMeasurementType.leftKnee,
      targetAngleDegrees: 90,
      toleranceDegrees: 10,
    );
    final result = evaluate({JointMeasurementType.rightKnee: 90}, [rule]);
    expect(result.rules.single.status, PoseRuleEvaluationStatus.unavailable);
  });
}
