import 'package:flutter_body/actions/body_rehab_action.dart';
import 'package:flutter_body/actions/lateral_step_action.dart';
import 'package:flutter_body/models/body_frame.dart';
import 'package:flutter_test/flutter_test.dart';

BodyFrame frame({required double leftAnkleX}) => BodyFrame(
      joints: {
        RehabJoint.leftHip: const Offset(.45, .45),
        RehabJoint.leftKnee: const Offset(.45, .65),
        RehabJoint.leftAnkle: Offset(leftAnkleX, .85),
        RehabJoint.rightHip: const Offset(.55, .45),
        RehabJoint.rightKnee: const Offset(.55, .65),
        RehabJoint.rightAnkle: const Offset(.54, .85),
      },
    );

void main() {
  test('horizontal step out then stable return counts exactly once', () {
    final action = LateralStepAction(
      difficulty: RehabDifficulty.easy,
      targetCount: 5,
    )
      ..selectTrainedLeg(isLeft: true)
      ..selectSimpleMode();

    action.update(frame(leftAnkleX: .46));
    for (var i = 0; i < 7; i++) {
      expect(action.update(frame(leftAnkleX: .30)).scored, isFalse);
    }
    final results = <bool>[];
    for (var i = 0; i < 4; i++) {
      results.add(action.update(frame(leftAnkleX: .46)).scored);
    }

    expect(results.where((value) => value), hasLength(1));
  });
}
