import 'dart:math' as math;

import 'package:flutter_body/features/pose_measurement/evaluation/pose_evaluation_engine.dart';
import 'package:flutter_body/features/pose_measurement/evaluation/pose_evaluation_result.dart';
import 'package:flutter_body/features/pose_measurement/evaluation/pose_measurement_rule.dart';
import 'package:flutter_body/features/pose_measurement/joint_angle_calculator.dart';
import 'package:flutter_body/features/pose_measurement/models/pose_frame.dart';
import 'package:flutter_body/features/pose_measurement/training/training_session_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = JointAngleCalculator();
  const rightAbduction = JointMeasurementType.rightShoulderAbduction;
  const leftAbduction = JointMeasurementType.leftShoulderAbduction;
  const rightFlexion = JointMeasurementType.rightShoulderFlexion;
  const leftFlexion = JointMeasurementType.leftShoulderFlexion;

  test('right and left measurements use anatomical side landmarks', () {
    final rightRaised = calculator.calculate(_rightSideRaise());
    expect(rightRaised[rightAbduction], closeTo(90, 1e-9));
    expect(rightRaised[leftAbduction], closeTo(0, 1e-9));

    final leftRaised = calculator.calculate(_leftSideRaise());
    expect(leftRaised[leftAbduction], closeTo(90, 1e-9));
    expect(leftRaised[rightAbduction], closeTo(0, 1e-9));
  });

  test('display mirroring never changes anatomical shoulder identity', () {
    final original = _rightSideRaise();
    final mirroredDisplay = PoseFrame(
      timestampMs: original.timestampMs,
      worldLandmarks: original.worldLandmarks,
      landmarks: {
        for (final entry in original.worldLandmarks.entries)
          entry.key: _point(1 - entry.value.x, entry.value.y, entry.value.z),
      },
      geometry: PoseGeometry(
        imageWidth: 480,
        imageHeight: 640,
        rotationDegrees: 0,
        mirrored: true,
        previewWidth: 1080,
        previewHeight: 1920,
        matrix: const [-1, 0, 1, 0, 1, 0, 0, 0, 1],
        revision: 2,
      ),
    );
    expect(
      calculator.calculate(mirroredDisplay)[rightAbduction],
      closeTo(calculator.calculate(original)[rightAbduction]!, 1e-9),
    );
  });

  test('side and forward raises remain directionally distinct', () {
    final side = calculator.calculate(_rightSideRaise());
    expect(side[rightAbduction], closeTo(90, 1e-9));
    expect(side[rightFlexion], closeTo(0, 1e-9));

    final forward = calculator.calculate(_rightForwardRaise());
    expect(forward[rightFlexion], closeTo(90, 1e-9));
    expect(forward[rightAbduction], closeTo(0, 1e-9));
  });

  test('arm down and low arm crossing torso cannot satisfy 90 abduction', () {
    final down = calculator.calculate(_frame());
    expect(down[rightAbduction], closeTo(0, 1e-9));

    final crossed = calculator.calculate(_frame(
      rightElbow: _point(0.4, -0.5, -0.5),
      rightWrist: _point(0.8, 0, -0.6),
    ));
    expect(crossed[rightAbduction], closeTo(0, 1e-9));
  });

  test('whole-body vertical-axis rotation preserves body-relative abduction',
      () {
    final original = _rightSideRaise();
    final rotated = PoseFrame(
      timestampMs: original.timestampMs,
      worldLandmarks: {
        for (final entry in original.worldLandmarks.entries)
          entry.key: _rotateAroundVertical(entry.value, math.pi / 3),
      },
    );
    expect(
      calculator.calculate(rotated)[rightAbduction],
      closeTo(calculator.calculate(original)[rightAbduction]!, 1e-8),
    );
    expect(
      calculator.calculate(rotated)[rightFlexion],
      closeTo(calculator.calculate(original)[rightFlexion]!, 1e-8),
    );
  });

  test('invalid torso or arm inputs return unavailable without fallback', () {
    final cases = <PoseFrame>[
      _without(_rightSideRaise(), PoseLandmarkType.leftHip),
      _replace(
        _rightSideRaise(),
        PoseLandmarkType.rightHip,
        _point(-1, 0, 0, visibility: 0.2),
      ),
      _replace(
        _rightSideRaise(),
        PoseLandmarkType.rightShoulder,
        _point(double.nan, -2, 0),
      ),
      _replace(
        _rightSideRaise(),
        PoseLandmarkType.rightElbow,
        _point(double.infinity, -2, 0),
      ),
      _frame(
        leftShoulder: _point(0, -2, 0),
        rightShoulder: _point(0, -2, 0),
      ),
      _frame(
        leftHip: _point(1, -2, 0),
        rightHip: _point(-1, -2, 0),
      ),
    ];
    for (final frame in cases) {
      final result = calculator.calculate(frame);
      expect(result[rightAbduction], isNull);
      expect(result[rightFlexion], isNull);
    }
  });

  test('shoulder pass plus bent elbow makes overall needs adjustment', () {
    final frame = _frame(
      rightElbow: _point(-3, -2, 0),
      rightWrist: _point(-3, 0, 0),
    );
    final measurements = calculator.calculate(frame);
    const rules = [
      PoseMeasurementRule(
        measurement: rightAbduction,
        targetAngleDegrees: 90,
        toleranceDegrees: 10,
      ),
      PoseMeasurementRule(
        measurement: JointMeasurementType.rightElbow,
        targetAngleDegrees: 170,
        toleranceDegrees: 10,
      ),
    ];
    final result = const PoseEvaluationEngine().evaluate(
      measurements: measurements,
      rules: rules,
    );
    expect(result.rules.first.status, PoseRuleEvaluationStatus.pass);
    expect(result.rules.last.status, isNot(PoseRuleEvaluationStatus.pass));
    expect(result.overallStatus, PoseOverallEvaluationStatus.needsAdjustment);
  });

  test('left forward raise is isolated from right and from abduction', () {
    final result = calculator.calculate(_frame(
      leftElbow: _point(1, -2, -2),
      leftWrist: _point(1, -2, -4),
    ));
    expect(result[leftFlexion], closeTo(90, 1e-9));
    expect(result[leftAbduction], closeTo(0, 1e-9));
    expect(result[rightFlexion], closeTo(0, 1e-9));
  });

  test('wrong raise direction cannot start hold but correct side raise can',
      () {
    const rule = PoseMeasurementRule(
      measurement: rightAbduction,
      targetAngleDegrees: 90,
      toleranceDegrees: 10,
    );
    const engine = PoseEvaluationEngine();
    final forward = engine.evaluate(
      measurements: calculator.calculate(_rightForwardRaise()),
      rules: const [rule],
    );
    final side = engine.evaluate(
      measurements: calculator.calculate(_rightSideRaise()),
      rules: const [rule],
    );
    final training = TrainingSessionStateMachine(
      TrainingSessionConfig(
        targetReps: 1,
        targetSets: 1,
        holdDuration: Duration(milliseconds: 1500),
      ),
    )..start();

    var state = training.update(forward.overallStatus, Duration.zero);
    expect(forward.overallStatus, PoseOverallEvaluationStatus.needsAdjustment);
    expect(state.phase, TrainingSessionPhase.waitingForCorrect);

    state = training.update(side.overallStatus, const Duration(seconds: 1));
    expect(side.overallStatus, PoseOverallEvaluationStatus.correct);
    expect(state.phase, TrainingSessionPhase.holding);
    expect(state.currentRep, 0);
  });
}

PoseFrame _rightSideRaise() => _frame(
      rightElbow: _point(-3, -2, 0),
      rightWrist: _point(-5, -2, 0),
    );

PoseFrame _rightForwardRaise() => _frame(
      rightElbow: _point(-1, -2, -2),
      rightWrist: _point(-1, -2, -4),
    );

PoseFrame _leftSideRaise() => _frame(
      leftElbow: _point(3, -2, 0),
      leftWrist: _point(5, -2, 0),
    );

PoseFrame _frame({
  PoseLandmark? leftShoulder,
  PoseLandmark? rightShoulder,
  PoseLandmark? leftHip,
  PoseLandmark? rightHip,
  PoseLandmark? leftElbow,
  PoseLandmark? rightElbow,
  PoseLandmark? leftWrist,
  PoseLandmark? rightWrist,
}) =>
    PoseFrame(timestampMs: 42, worldLandmarks: {
      PoseLandmarkType.leftShoulder: leftShoulder ?? _point(1, -2, 0),
      PoseLandmarkType.rightShoulder: rightShoulder ?? _point(-1, -2, 0),
      PoseLandmarkType.leftHip: leftHip ?? _point(1, 0, 0),
      PoseLandmarkType.rightHip: rightHip ?? _point(-1, 0, 0),
      PoseLandmarkType.leftElbow: leftElbow ?? _point(1, -1, 0),
      PoseLandmarkType.rightElbow: rightElbow ?? _point(-1, -1, 0),
      PoseLandmarkType.leftWrist: leftWrist ?? _point(1, 0, 0),
      PoseLandmarkType.rightWrist: rightWrist ?? _point(-1, 0, 0),
      PoseLandmarkType.leftKnee: _point(1, 2, 0),
      PoseLandmarkType.rightKnee: _point(-1, 2, 0),
      PoseLandmarkType.leftAnkle: _point(1, 4, 0),
      PoseLandmarkType.rightAnkle: _point(-1, 4, 0),
    });

PoseFrame _without(PoseFrame source, PoseLandmarkType type) {
  final world = Map<PoseLandmarkType, PoseLandmark>.of(source.worldLandmarks)
    ..remove(type);
  return PoseFrame(timestampMs: source.timestampMs, worldLandmarks: world);
}

PoseFrame _replace(
  PoseFrame source,
  PoseLandmarkType type,
  PoseLandmark replacement,
) {
  final world = Map<PoseLandmarkType, PoseLandmark>.of(source.worldLandmarks)
    ..[type] = replacement;
  return PoseFrame(timestampMs: source.timestampMs, worldLandmarks: world);
}

PoseLandmark _rotateAroundVertical(PoseLandmark point, double radians) {
  final cosine = math.cos(radians);
  final sine = math.sin(radians);
  return _point(
    point.x * cosine + point.z * sine,
    point.y,
    -point.x * sine + point.z * cosine,
    visibility: point.visibility,
    presence: point.presence,
  );
}

PoseLandmark _point(
  double x,
  double y,
  double z, {
  double? visibility = 0.95,
  double? presence = 0.95,
}) =>
    PoseLandmark(
      x: x,
      y: y,
      z: z,
      visibility: visibility,
      presence: presence,
    );
