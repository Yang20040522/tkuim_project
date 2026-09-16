import 'package:flutter_body/actions/body_rehab_action.dart';
import 'package:flutter_body/actions/reach_action.dart';
import 'package:flutter_body/models/body_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('promotion keeps the selected hand and resets the repetition state', () {
    final action = ReachAction(targetCount: 1)..selectLeftHand();
    expect(action.update(_rest).scored, isFalse);
    expect(action.update(_raised).scored, isFalse);
    expect(action.update(_rest).leveledUp, isTrue);
    expect(action.isPendingLevelUp, isTrue);

    action.confirmLevelUp(customTargetReps: 12);
    expect(action.difficulty, RehabDifficulty.medium);
    expect(action.handSelected, isTrue);
    expect(action.successCount, 0);
    expect(action.isPendingLevelUp, isFalse);
    expect(action.update(_rest).scored, isFalse);
    expect(action.successCount, 0);
  });
}

const _rest = BodyFrame(
  joints: {
    RehabJoint.leftShoulder: Offset(0.5, 0.4),
    RehabJoint.leftHip: Offset(0.5, 0.8),
    RehabJoint.leftWrist: Offset(0.5, 0.6),
  },
);

const _raised = BodyFrame(
  joints: {
    RehabJoint.leftShoulder: Offset(0.5, 0.4),
    RehabJoint.leftHip: Offset(0.5, 0.8),
    RehabJoint.leftWrist: Offset(0.5, 0.1),
  },
);
