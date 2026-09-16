import 'package:flutter_body/actions/body_rehab_action.dart';
import 'package:flutter_body/actions/standing_knee_raise_action.dart';
import 'package:flutter_body/features/rehab/body_training_level_progress.dart';
import 'package:flutter_body/models/body_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('level transition snapshots old progress and resets atomically', () {
    final progress = BodyTrainingLevelProgress(
      level: RehabDifficulty.easy,
      targetReps: 3,
    );
    final history = <CompletedBodyTrainingLevel>[];

    for (var i = 0; i < 3; i++) {
      progress.recordScoredRep();
    }
    final completed = progress.beginTransition();
    history.add(completed!);

    expect(completed.level, RehabDifficulty.easy);
    expect(completed.completedReps, 3);
    expect(completed.targetReps, 3);
    expect(progress.beginTransition(), isNull);

    progress.completeTransition(
      nextLevel: RehabDifficulty.medium,
      nextTargetReps: 5,
    );
    expect(progress.level, RehabDifficulty.medium);
    expect(progress.completedReps, 0);
    expect(progress.targetReps, 5);

    // One frame already buffered across the boundary is discarded.
    expect(progress.consumePoseFrameBlock(), isTrue);
    expect(progress.consumePoseFrameBlock(), isFalse);
    progress.recordScoredRep();
    expect(progress.completedReps, 1);
    expect(history, hasLength(1));
  });

  test('starting at level 2 advances directly to level 3', () {
    final progress = BodyTrainingLevelProgress(
      level: RehabDifficulty.medium,
      targetReps: 2,
    );
    progress.recordScoredRep();
    progress.recordScoredRep();

    final completed = progress.beginTransition()!;
    expect(completed.level, RehabDifficulty.medium);
    progress.completeTransition(
      nextLevel: RehabDifficulty.hard,
      nextTargetReps: 4,
    );

    expect(progress.level, RehabDifficulty.hard);
    expect(progress.completedReps, 0);
    expect(progress.targetReps, 4);
  });

  test('automatic promotion preserves 12 in action and displayed progress', () {
    final action = StandingKneeRaiseAction(targetCount: 12)..selectRightLeg();
    final progress = BodyTrainingLevelProgress(
      level: RehabDifficulty.easy,
      targetReps: 12,
    );
    for (var i = 0; i < 12; i++) {
      expect(action.update(_raisedRightKnee).scored, isTrue);
      progress.recordScoredRep();
      action.update(_standing);
    }
    expect(action.isPendingLevelUp, isTrue);
    expect(progress.beginTransition()!.targetReps, 12);
    progress.completeAutomaticTransition(
      action: action,
      nextLevel: RehabDifficulty.medium,
    );
    expect(action.difficulty, RehabDifficulty.medium);
    expect(action.targetCount, progress.targetReps);
    expect(progress.targetReps, 12);
    expect(progress.completedReps, 0);
    expect(action.successCount, 0);
    expect(action.isPendingLevelUp, isFalse);
    expect(progress.consumePoseFrameBlock(), isTrue);

    // The next stage does not count the same raised pose twice.
    expect(action.update(_raisedRightKnee).scored, isFalse);
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
