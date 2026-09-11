import 'package:flutter_body/actions/body_rehab_action.dart';
import 'package:flutter_body/actions/standing_knee_raise_action.dart';
import 'package:flutter_body/models/body_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('level-up requires lowering the knee before a new rep can score', () {
    final action = StandingKneeRaiseAction(
      difficulty: RehabDifficulty.easy,
      targetCount: 1,
    )..selectRightLeg();

    final levelUp = action.update(_raisedRightKnee);
    expect(levelUp.scored, isTrue);
    expect(levelUp.leveledUp, isTrue);
    expect(action.isPendingLevelUp, isTrue);

    action.confirmLevelUp(customTargetReps: 2);
    expect(action.difficulty, RehabDifficulty.medium);

    // The same sustained raise is not a new physical repetition.
    expect(action.update(_raisedRightKnee).scored, isFalse);
    expect(action.successCount, 0);

    expect(action.update(_standing).scored, isFalse);
    expect(action.update(_raisedRightKnee).scored, isTrue);
    expect(action.successCount, 1);
    expect(action.isPendingLevelUp, isFalse);
  });
}

const _raisedRightKnee = BodyFrame(
  joints: {
    RehabJoint.leftShoulder: Offset(0.45, 0.20),
    RehabJoint.rightShoulder: Offset(0.55, 0.20),
    RehabJoint.leftHip: Offset(0.45, 0.60),
    RehabJoint.leftKnee: Offset(0.45, 0.75),
    RehabJoint.leftAnkle: Offset(0.45, 0.90),
    RehabJoint.rightHip: Offset(0.55, 0.60),
    RehabJoint.rightKnee: Offset(0.55, 0.45),
    RehabJoint.rightAnkle: Offset(0.75, 0.45),
  },
);

const _standing = BodyFrame(
  joints: {
    RehabJoint.leftShoulder: Offset(0.45, 0.20),
    RehabJoint.rightShoulder: Offset(0.55, 0.20),
    RehabJoint.leftHip: Offset(0.45, 0.60),
    RehabJoint.leftKnee: Offset(0.45, 0.75),
    RehabJoint.leftAnkle: Offset(0.45, 0.90),
    RehabJoint.rightHip: Offset(0.55, 0.60),
    RehabJoint.rightKnee: Offset(0.55, 0.75),
    RehabJoint.rightAnkle: Offset(0.55, 0.90),
  },
);
