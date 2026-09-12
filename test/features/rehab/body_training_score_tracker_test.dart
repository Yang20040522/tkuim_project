import 'package:flutter_body/actions/body_rehab_action.dart';
import 'package:flutter_body/features/rehab/body_training_score_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const noScore = RehabFeedback();
  const scored = RehabFeedback(scored: true, prompt: '完成一次');

  group('BodyTrainingScoreTracker', () {
    test('one score is produced only for each authoritative scored rep', () {
      final tracker = BodyTrainingScoreTracker();

      expect(
        tracker.observe(
          feedback: noScore,
          displayedPrompt: '很好，繼續抬高',
          skeletonValid: true,
          trainingActive: true,
        ),
        isNull,
      );
      expect(
        tracker.observe(
          feedback: scored,
          displayedPrompt: '完成一次',
          skeletonValid: true,
          trainingActive: true,
        ),
        100,
      );
      expect(tracker.repScores, [100]);
      expect(tracker.averageScore, 100);
    });

    test('continuous identical correction is deducted once', () {
      final tracker = BodyTrainingScoreTracker();

      for (var frame = 0; frame < 20; frame++) {
        tracker.observe(
          feedback: noScore,
          displayedPrompt: '請坐正，不要往後靠',
          skeletonValid: true,
          trainingActive: true,
        );
      }

      final result = tracker.observe(
        feedback: scored,
        displayedPrompt: '完成一次',
        skeletonValid: true,
        trainingActive: true,
      );
      expect(result, 92);
      expect(tracker.mistakeLogs, hasLength(1));
    });

    test('correction may count again after it disappears', () {
      final tracker = BodyTrainingScoreTracker();

      tracker.observe(
        feedback: noScore,
        displayedPrompt: '試著把膝蓋再抬高',
        skeletonValid: true,
        trainingActive: true,
      );
      tracker.observe(
        feedback: noScore,
        displayedPrompt: null,
        skeletonValid: true,
        trainingActive: true,
      );
      tracker.observe(
        feedback: noScore,
        displayedPrompt: '試著把膝蓋再抬高',
        skeletonValid: true,
        trainingActive: true,
      );

      expect(
        tracker.observe(
          feedback: scored,
          displayedPrompt: '完成一次',
          skeletonValid: true,
          trainingActive: true,
        ),
        84,
      );
    });

    test('missing skeleton waiting pause and success prompts do not deduct',
        () {
      final tracker = BodyTrainingScoreTracker();

      for (final observation in <({String prompt, bool skeleton, bool active})>[
        (prompt: '請坐正，不要往後靠', skeleton: false, active: true),
        (prompt: '請先選擇訓練腳', skeleton: true, active: true),
        (prompt: '請坐正，不要往後靠', skeleton: true, active: false),
        (prompt: '太棒了！解鎖下一個難度！', skeleton: true, active: true),
      ]) {
        tracker.observe(
          feedback: noScore,
          displayedPrompt: observation.prompt,
          skeletonValid: observation.skeleton,
          trainingActive: observation.active,
        );
      }

      expect(
        tracker.observe(
          feedback: scored,
          displayedPrompt: '完成一次',
          skeletonValid: true,
          trainingActive: true,
        ),
        100,
      );
    });

    test('camera or skeleton interruption does not duplicate a correction', () {
      final tracker = BodyTrainingScoreTracker();

      tracker.observe(
        feedback: noScore,
        displayedPrompt: '請坐正，不要往後靠',
        skeletonValid: true,
        trainingActive: true,
      );
      tracker.observe(
        feedback: noScore,
        displayedPrompt: '請將身體放入鏡頭範圍內',
        skeletonValid: false,
        trainingActive: true,
      );
      tracker.observe(
        feedback: noScore,
        displayedPrompt: '請將身體放入鏡頭範圍內',
        skeletonValid: true,
        trainingActive: true,
      );
      tracker.observe(
        feedback: noScore,
        displayedPrompt: '請坐正，不要往後靠',
        skeletonValid: true,
        trainingActive: true,
      );

      expect(
        tracker.observe(
          feedback: scored,
          displayedPrompt: '完成一次',
          skeletonValid: true,
          trainingActive: true,
        ),
        92,
      );
    });

    test('scores are clamped and reset separates difficulty levels', () {
      final tracker = BodyTrainingScoreTracker(correctionPenalty: 30);
      const corrections = [
        '不要後仰',
        '支撐腳晃動',
        '手掉下來了',
        '放太快了',
      ];
      for (final correction in corrections) {
        tracker.observe(
          feedback: noScore,
          displayedPrompt: correction,
          skeletonValid: true,
          trainingActive: true,
        );
      }
      expect(
        tracker.observe(
          feedback: scored,
          displayedPrompt: '完成一次',
          skeletonValid: true,
          trainingActive: true,
        ),
        0,
      );

      tracker.reset();
      expect(tracker.repScores, isEmpty);
      expect(tracker.averageScore, isNull);
      expect(tracker.mistakeLogs, isEmpty);
    });
  });
}
