import '../../../models/assignable_exercise.dart';
import '../../../models/custom_rehab_exercise.dart';
import '../models/joint_angle_frame.dart';
import 'pose_measurement_rule.dart';

/// Resolves once per measurement session; no rules are reconstructed per frame.
class PoseMeasurementRuleResolver {
  const PoseMeasurementRuleResolver();

  List<PoseMeasurementRule> resolve(
    AssignableExercise exercise, {
    CustomRehabExercise? customExercise,
  }) {
    if (exercise.type == AssignableExerciseType.custom) {
      // CUSTOM EvaluationRule is GLB bone-local XYZ rotation. It cannot safely
      // be adapted to a MediaPipe anatomical three-point angle. Only the
      // independent poseMeasurementRules domain is accepted here.
      if (customExercise == null || customExercise.id != exercise.id) {
        return const [];
      }
      return customExercise.poseMeasurementRules;
    }
    return switch (_normalize(exercise.name)) {
      '手肘屈伸訓練' => _elbowExtensionRules,
      '坐站訓練' => _sitToStandRules,
      _ => const [],
    };
  }

  static String _normalize(String value) =>
      value.replaceAll(RegExp(r'\s+'), '');

  // Medium endpoint from the existing ElbowForwardAction (150°). A tolerance
  // supports the verified 130°/150°/165° difficulty endpoints without adding
  // difficulty or repetition semantics to this measurement-only page.
  static const _elbowExtensionRules = <PoseMeasurementRule>[
    PoseMeasurementRule(
      measurement: JointMeasurementType.leftElbow,
      targetAngleDegrees: 150,
      toleranceDegrees: 20,
    ),
    PoseMeasurementRule(
      measurement: JointMeasurementType.rightElbow,
      targetAngleDegrees: 150,
      toleranceDegrees: 20,
    ),
  ];

  // Existing SitToStandAction's easy endpoint is 140°. This evaluates only
  // that endpoint pose and deliberately does not implement its movement cycle.
  static const _sitToStandRules = <PoseMeasurementRule>[
    PoseMeasurementRule(
      measurement: JointMeasurementType.leftKnee,
      targetAngleDegrees: 140,
      toleranceDegrees: 10,
    ),
    PoseMeasurementRule(
      measurement: JointMeasurementType.rightKnee,
      targetAngleDegrees: 140,
      toleranceDegrees: 10,
    ),
  ];
}
