import 'package:flutter/foundation.dart';

import '../joint_angle_calculator.dart';
import '../pose_camera_controller.dart';
import 'pose_evaluation_engine.dart';
import 'pose_evaluation_result.dart';
import 'pose_evaluation_stabilizer.dart';
import 'pose_measurement_rule.dart';

class PoseEvaluationSnapshot {
  const PoseEvaluationSnapshot({
    required this.measurements,
    required this.evaluation,
    required this.inferenceMs,
  });

  final JointAngleFrame measurements;
  final StabilizedPoseEvaluation evaluation;
  final double inferenceMs;
}

/// Session-owned bridge from camera frames to lightweight pure-Dart evaluation.
class PoseEvaluationSession {
  PoseEvaluationSession({
    required PoseCameraController camera,
    required List<PoseMeasurementRule> rules,
    JointAngleCalculator angleCalculator = const JointAngleCalculator(),
    PoseEvaluationEngine engine = const PoseEvaluationEngine(),
    PoseEvaluationStabilizer? stabilizer,
  })  : _camera = camera,
        rules = List.unmodifiable(rules),
        _angleCalculator = angleCalculator,
        _engine = engine,
        _stabilizer = stabilizer ?? PoseEvaluationStabilizer() {
    _camera.frame.addListener(_onFrame);
    reset();
  }

  final PoseCameraController _camera;
  final List<PoseMeasurementRule> rules;
  final JointAngleCalculator _angleCalculator;
  final PoseEvaluationEngine _engine;
  final PoseEvaluationStabilizer _stabilizer;
  late final ValueNotifier<PoseEvaluationSnapshot> snapshot;
  bool _snapshotInitialized = false;
  bool _disposed = false;

  void _onFrame() {
    if (_disposed) return;
    final frame = _camera.frame.value;
    if (frame == null) {
      reset();
      return;
    }
    final measurements = _angleCalculator.calculate(frame);
    final raw = _engine.evaluate(measurements: measurements, rules: rules);
    snapshot.value = PoseEvaluationSnapshot(
      measurements: measurements,
      evaluation: StabilizedPoseEvaluation(
        raw: raw,
        presentedOverallStatus: _stabilizer.update(raw.overallStatus),
      ),
      inferenceMs: frame.inferenceMs,
    );
  }

  void reset() {
    if (_disposed) return;
    _stabilizer.reset(hasRules: rules.isNotEmpty);
    final measurements = JointAngleFrame(timestampMs: 0, angles: const {});
    final raw = _engine.evaluate(measurements: measurements, rules: rules);
    final value = PoseEvaluationSnapshot(
      measurements: measurements,
      evaluation: StabilizedPoseEvaluation(
        raw: raw,
        presentedOverallStatus: _stabilizer.presented,
      ),
      inferenceMs: 0,
    );
    if (_snapshotInitialized) {
      snapshot.value = value;
    } else {
      snapshot = ValueNotifier(value);
      _snapshotInitialized = true;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _camera.frame.removeListener(_onFrame);
    snapshot.dispose();
  }
}
