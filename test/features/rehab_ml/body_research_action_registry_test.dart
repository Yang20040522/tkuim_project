import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/actions/body_rehab_action.dart';
import 'package:flutter_body/actions/draw_circle_action.dart';
import 'package:flutter_body/actions/reach_action.dart';
import 'package:flutter_body/actions/raise_both_arms_action.dart';
import 'package:flutter_body/actions/elbow_forward_action.dart';
import 'package:flutter_body/actions/sit_to_stand_action.dart';
import 'package:flutter_body/actions/lateral_step_action.dart';
import 'package:flutter_body/actions/standing_knee_raise_action.dart';
import 'package:flutter_body/features/rehab_ml/body_research_action_registry.dart';
import 'package:flutter_body/models/body_frame.dart';

class _DiagnosticAction implements BodyRehabAction {
  @override String get title => 'body_skeleton_test';
  @override String get initialHint => '';
  @override String get difficultyLabel => '';
  @override RehabFeedback update(BodyFrame frame) => RehabFeedback.none;
}

void main() {
  test('seven formal actions resolve and diagnostic action is excluded', () {
    final actions = <BodyRehabAction>[
      StandingKneeRaiseAction(), DrawCircleAction(), ReachAction(),
      RaiseBothArmsAction(), ElbowForwardAction(), SitToStandAction(),
      LateralStepAction(),
    ];
    expect(actions.map((action) =>
        BodyResearchActionRegistry.forAction(action)?.actionId).toList(), [
      'standing_knee_raise', 'draw_circle', 'overhead_reach',
      'raise_both_arms', 'elbow_forward', 'sit_to_stand', 'lateral_step',
    ]);
    expect(BodyResearchActionRegistry.forAction(_DiagnosticAction()), isNull);
    expect(BodyResearchActionRegistry.actions.first.schemaVersion, 3);
    expect(BodyResearchActionRegistry.actions.skip(1)
        .every((contract) => contract.schemaVersion == 4), true);
    expect(BodyResearchActionRegistry.actions.map((contract) =>
        contract.definitionVersion).toSet().length, 7);
  });

  test('resolvers read authoritative action side and leg mode', () {
    final standing = StandingKneeRaiseAction();
    final step = LateralStepAction();
    final reach = ReachAction();
    final circle = DrawCircleAction();
    final standingContract = BodyResearchActionRegistry.forAction(standing)!;
    final stepContract = BodyResearchActionRegistry.forAction(step)!;
    final reachContract = BodyResearchActionRegistry.forAction(reach)!;
    final circleContract = BodyResearchActionRegistry.forAction(circle)!;
    expect(standingContract.side(standing), isNull);
    expect(stepContract.side(step), isNull);
    expect(reachContract.side(reach), isNull);
    expect(circleContract.side(circle), isNull);
    standing.selectTrainedLeg(isLeft: true);
    standing.selectSimpleMode();
    expect(standingContract.side(standing), 'left');
    standing.selectHardMode();
    expect(standingContract.side(standing), 'right');
    step.selectTrainedLeg(isLeft: false);
    step.selectSimpleMode();
    expect(stepContract.side(step), 'right');
    expect(stepContract.mode!(step), 'simple');
    step.selectHardMode();
    expect(stepContract.side(step), 'left');
    expect(stepContract.mode!(step), 'hard');
    reach.selectLeftHand();
    expect(reachContract.side(reach), 'left');
    reach.selectRightHand();
    expect(reachContract.side(reach), 'right');
    circle.update(BodyFrame(joints: {
      RehabJoint.leftShoulder: const Offset(.4, .4),
      RehabJoint.rightShoulder: const Offset(.6, .4),
      RehabJoint.leftWrist: const Offset(.4, .2),
      RehabJoint.rightWrist: const Offset(.6, .8),
    }));
    expect(circleContract.side(circle), 'left');
    for (final action in <BodyRehabAction>[
      RaiseBothArmsAction(), ElbowForwardAction(), SitToStandAction()]) {
      expect(BodyResearchActionRegistry.forAction(action)!.side(action), 'bilateral');
    }
  });
}
