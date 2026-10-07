import '../../actions/body_rehab_action.dart';
import '../../actions/standing_knee_raise_action.dart';
import '../../actions/draw_circle_action.dart';
import '../../actions/reach_action.dart';
import '../../actions/raise_both_arms_action.dart';
import '../../actions/elbow_forward_action.dart';
import '../../actions/sit_to_stand_action.dart';
import '../../actions/lateral_step_action.dart';

/// Explicit research capability; diagnostic body test is intentionally absent.
class BodyResearchActionContract {
  const BodyResearchActionContract(this.actionId, this.displayName,
      this.schemaVersion, this.definitionVersion, this.side,
      {this.mode});
  final String actionId, displayName, definitionVersion;
  final int schemaVersion;
  final String? Function(BodyRehabAction) side;
  final String? Function(BodyRehabAction)? mode;
}

class BodyResearchActionRegistry {
  static final List<BodyResearchActionContract> actions = [
    BodyResearchActionContract('standing_knee_raise', '站姿抬腳式訓練', 3,
        'standing-knee-raise-body-v2',
        (action) => _side((action as StandingKneeRaiseAction).movingLegIsLeft)),
    BodyResearchActionContract('draw_circle', '畫圓訓練', 4,
        'draw-circle-body-review-v1',
        (action) => _side((action as DrawCircleAction).activeArmIsLeft)),
    BodyResearchActionContract('overhead_reach', '伸手舉高訓練', 4,
        'overhead-reach-body-review-v1',
        (action) => _side((action as ReachAction).selectedHandIsLeft)),
    BodyResearchActionContract('raise_both_arms', '雙手抬舉式', 4,
        'raise-both-arms-body-review-v1', (action) => 'bilateral'),
    BodyResearchActionContract('elbow_forward', '手肘屈伸訓練', 4,
        'elbow-forward-body-review-v1', (action) => 'bilateral'),
    BodyResearchActionContract('sit_to_stand', '坐站訓練', 4,
        'sit-to-stand-body-review-v1', (action) => 'bilateral'),
    BodyResearchActionContract('lateral_step', '側跨步訓練', 4,
        'lateral-step-body-review-v1',
        (action) => _side((action as LateralStepAction).movingLegIsLeft),
        mode: (action) => (action as LateralStepAction).researchMovementMode),
  ];

  static BodyResearchActionContract? forAction(BodyRehabAction action) {
    if (action is StandingKneeRaiseAction) return actions[0];
    if (action is DrawCircleAction) return actions[1];
    if (action is ReachAction) return actions[2];
    if (action is RaiseBothArmsAction) return actions[3];
    if (action is ElbowForwardAction) return actions[4];
    if (action is SitToStandAction) return actions[5];
    if (action is LateralStepAction) return actions[6];
    return null;
  }
  static String? _side(bool? left) => left == null ? null : left ? 'left' : 'right';
}
