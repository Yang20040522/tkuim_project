import 'package:flutter_body/features/history/history_session_group.dart';
import 'package:flutter_body/models/training_action.dart';
import 'package:flutter_test/flutter_test.dart';

TrainingRecord record(String time, int level, {String? sessionId}) =>
    TrainingRecord(
      sessionId: sessionId,
      timestamp: time,
      actionName: '側跨步訓練',
      difficulty: level,
      durationSeconds: 5,
      mistakeLogs: const [],
      completedReps: 5,
      targetReps: 5,
    );

void main() {
  test('groups explicit automatic sessions', () {
    final groups = groupTrainingRecords([
      record('2026-09-10 10:00:00', 1, sessionId: 'auto:a'),
      record('2026-09-10 10:01:00', 2, sessionId: 'auto:a'),
      record('2026-09-10 10:02:00', 1, sessionId: 'manual:b'),
    ]);
    expect(groups, hasLength(2));
    expect(groups.singleWhere((g) => g.records.length == 2).levels, [1, 2]);
  });

  test('legacy fallback requires same action, ten minutes and level plus one',
      () {
    final groups = groupTrainingRecords([
      record('2026-09-10 10:00:00', 1),
      record('2026-09-10 10:09:59', 2),
      record('2026-09-10 10:20:01', 3),
    ]);
    expect(groups.map((g) => g.records.length), containsAll([2, 1]));
  });
}
