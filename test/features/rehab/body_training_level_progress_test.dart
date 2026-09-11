import 'package:flutter_body/actions/body_rehab_action.dart';
import 'package:flutter_body/features/rehab/body_training_level_progress.dart';
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
}
