import 'package:flutter_body/models/training_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrainingRecord JSON', () {
    test('round trips completed reps and separate video fields', () {
      final record = TrainingRecord(
        id: 123,
        timestamp: '2026-09-09 16:25:44',
        actionName: '伸手舉高訓練',
        difficulty: 2,
        durationSeconds: 9,
        completedReps: 2,
        targetReps: 5,
        mistakeLogs: const ['第1次：側捏動作不夠流暢'],
        videoPath: '/data/user/0/app/training.mp4',
        videoUrl: 'https://example.test/api/training-history/123/video',
        isSynced: true,
        isVideoSynced: true,
        averageBodyScore: 92.5,
        bodyRepScores: const [90, 95],
        templateScore: 88.25,
        templateId: 'template-1',
        templateName: '標準抬腳',
        templateValidRepCount: 2,
        templateRepScores: const [86.5, 90],
        templateDifferenceSummary: const ['右膝軌跡差異較大'],
      );

      final decoded = TrainingRecord.fromJson(record.toJson());

      expect(decoded.id, 123);
      expect(decoded.actionName, '伸手舉高訓練');
      expect(decoded.completedReps, 2);
      expect(decoded.targetReps, 5);
      expect(decoded.videoPath, '/data/user/0/app/training.mp4');
      expect(
        decoded.videoUrl,
        'https://example.test/api/training-history/123/video',
      );
      expect(decoded.isVideoSynced, isTrue);
      expect(decoded.averageBodyScore, 92.5);
      expect(decoded.bodyRepScores, [90, 95]);
      expect(decoded.templateScore, 88.25);
      expect(decoded.templateId, 'template-1');
      expect(decoded.templateName, '標準抬腳');
      expect(decoded.templateValidRepCount, 2);
      expect(decoded.templateRepScores, [86.5, 90]);
      expect(decoded.templateDifferenceSummary, ['右膝軌跡差異較大']);
    });

    test('old JSON does not crash and local video remains eligible to retry',
        () {
      final decoded = TrainingRecord.fromJson({
        'timestamp': '2026-09-01 10:00:00',
        'actionName': '翻掌訓練',
        'difficulty': 1,
        'durationSeconds': 8,
        'mistakeLogs': <String>[],
        'targetReps': 5,
        'videoPath': '/old/local.mp4',
        'isSynced': true,
      });

      expect(decoded.completedReps, 0);
      expect(decoded.videoUrl, isNull);
      expect(decoded.isSynced, isTrue);
      expect(decoded.isVideoSynced, isFalse);
    });

    test('old JSON without video is treated as having no video work', () {
      final decoded = TrainingRecord.fromJson({
        'timestamp': '2026-09-01 10:00:00',
        'actionName': '翻掌訓練',
        'mistakeLogs': <String>[],
      });

      expect(decoded.completedReps, 0);
      expect(decoded.targetReps, 10);
      expect(decoded.isVideoSynced, isTrue);
      expect(decoded.averageBodyScore, isNull);
      expect(decoded.templateScore, isNull);
      expect(decoded.templateValidRepCount, 0);
    });
  });
}
