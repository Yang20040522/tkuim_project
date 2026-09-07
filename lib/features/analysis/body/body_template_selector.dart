import '../../../models/training_action.dart';
import '../models/environment_metadata.dart';
import '../models/motion_action_registry.dart';
import 'body_motion_template.dart';

class BodyTemplateSelector {
  const BodyTemplateSelector._();

  static String get standingKneeRaiseActionId =>
      MotionActionRegistry.forActionType(ActionType.wipeBody).actionId;

  static bool matchesStandingKneeRaise(BodyMotionTemplate template) {
    final capability = MotionActionRegistry.resolve(
          template.actionId,
          modelType: MotionTemplateModelType.body,
        ) ??
        MotionActionRegistry.resolve(
          template.actionType,
          modelType: MotionTemplateModelType.body,
        );
    return capability?.actionId == standingKneeRaiseActionId;
  }

  static List<BodyMotionTemplate> standingKneeRaiseCandidates(
    Iterable<BodyMotionTemplate> templates,
  ) {
    final candidates = templates.where(matchesStandingKneeRaise).toList();
    candidates.sort(_newestFirst);
    return List<BodyMotionTemplate>.unmodifiable(candidates);
  }

  static BodyMotionTemplate? selectStandingKneeRaise({
    required Iterable<BodyMotionTemplate> templates,
    BodySide? movementSide,
  }) {
    final candidates = standingKneeRaiseCandidates(templates);
    if (candidates.isEmpty) return null;

    if (movementSide == BodySide.left || movementSide == BodySide.right) {
      for (final template in candidates) {
        if (template.environment.movementSide == movementSide) return template;
      }
      for (final template in candidates) {
        final side = template.environment.movementSide;
        if (side == BodySide.none || side == BodySide.both) return template;
      }
      return null;
    }
    return candidates.first;
  }

  static int _newestFirst(
    BodyMotionTemplate left,
    BodyMotionTemplate right,
  ) {
    final createdComparison = right.createdAt.compareTo(left.createdAt);
    if (createdComparison != 0) return createdComparison;
    return right.templateId.compareTo(left.templateId);
  }
}
