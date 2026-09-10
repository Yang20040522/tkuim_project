import 'package:flutter_body/models/training_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrainingRecord JSON compatibility', () {
    test('round trips all synchronized history fields', () {
      final record = TrainingRecord(
        id: 123,
        sessionId: 'auto:session-1',
        timestamp: '2026-09-09 16:25:44',
        actionName: '伸手舉高訓練',
        difficulty: 2,
        durationSeconds: 9,
        completedReps: 2,
        targetReps: 5,
        mistakeLogs: const ['動作偏快'],
        videoPath: '/local/training.mp4',
        videoUrl: 'https://example.test/api/training-history/123/video',
        isSynced: true,
        isVideoSynced: true,
      );

      final decoded = TrainingRecord.fromJson(record.toJson());

      expect(decoded.id, 123);
      expect(decoded.sessionId, 'auto:session-1');
      expect(decoded.completedReps, 2);
      expect(decoded.videoUrl, contains('/123/video'));
      expect(decoded.isVideoSynced, isTrue);
      expect(decoded.hasVideo, isTrue);
      expect(decoded.isAutomaticLevelUpSession, isTrue);
    });

    test('legacy JSON keeps missing fields backward compatible', () {
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

      expect(decoded.id, isNull);
      expect(decoded.sessionId, isNull);
      expect(decoded.completedReps, 0);
      expect(decoded.videoUrl, isNull);
      expect(decoded.isVideoSynced, isFalse);
    });

    test('legacy JSON without video has no pending video work', () {
      final decoded = TrainingRecord.fromJson({
        'timestamp': '2026-09-01 10:00:00',
        'actionName': '翻掌訓練',
        'mistakeLogs': <String>[],
      });

      expect(decoded.completedReps, 0);
      expect(decoded.targetReps, 10);
      expect(decoded.isVideoSynced, isTrue);
    });
  });
}
