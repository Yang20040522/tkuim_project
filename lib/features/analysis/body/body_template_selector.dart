import '../../../models/training_action.dart';
import '../models/environment_metadata.dart';
import 'body_motion_template.dart';

class BodyTemplateSelector {
  const BodyTemplateSelector._();

  static String get standingKneeRaiseActionId => ActionType.wipeBody.name;

  static bool matchesStandingKneeRaise(BodyMotionTemplate template) {
    final actionType = template.actionType.trim();
    if (actionType == standingKneeRaiseActionId) return true;

    // Phase 1 stored its preset label in actionType. Keep this narrow legacy
    // fallback so existing local templates remain usable.
    return actionType == '站姿抬腳式訓練' || actionType.contains('站姿抬腳');
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
