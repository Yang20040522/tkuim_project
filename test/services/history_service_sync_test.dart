import 'dart:io';

import 'package:flutter_body/models/training_action.dart';
import 'package:flutter_body/services/history_repository.dart';
import 'package:flutter_body/services/history_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('metadata sends session/reps, stores backend id and syncs video',
      () async {
    final directory = await Directory.systemTemp.createTemp('tv-history-test');
    addTearDown(() => directory.delete(recursive: true));
    final video = File('${directory.path}/result.mp4');
    await video.writeAsBytes([0, 1, 2]);

    final repository = _MemoryHistoryRepository([
      TrainingRecord(
        sessionId: 'auto:test-session',
        timestamp: '2026-09-10 12:00:00',
        actionName: '側跨步訓練',
        difficulty: 2,
        durationSeconds: 8,
        mistakeLogs: const ['支撐腳晃動'],
        videoPath: video.path,
        completedReps: 6,
        targetReps: 8,
      ),
    ]);
    final gateway = _FakeGateway();
    final service = HistoryService.withRepository(
      repository,
      gateway: gateway,
    );

    final result = await service.uploadPendingRecords(userId: 9);

    expect(result.success, 1);
    expect(gateway.uploaded.single.sessionId, 'auto:test-session');
    expect(gateway.uploaded.single.completedReps, 6);
    expect(gateway.uploaded.single.targetReps, 8);
    expect(gateway.videoHistoryIds, [77]);
    expect(repository.records.single.id, 77);
    expect(repository.records.single.isSynced, isTrue);
    expect(repository.records.single.isVideoSynced, isTrue);
  });

  test(
      'cloud history merges session and completed reps without replacing local',
      () async {
    final repository = _MemoryHistoryRepository([]);
    final gateway = _FakeGateway()
      ..cloudRows = [
        {
          'id': 88,
          'sessionId': 'manual:cloud',
          'timestamp': '2026-09-10 13:00:00',
          'actionName': '翻掌訓練',
          'difficulty': 1,
          'durationSeconds': 4,
          'mistakeLogs': <String>[],
          'completedReps': 4,
          'targetReps': 4,
          'isSynced': true,
          'isVideoSynced': true,
        },
      ];
    final service = HistoryService.withRepository(repository, gateway: gateway);

    expect(await service.syncFromCloud(userId: 9), 1);
    expect(repository.records.single.sessionId, 'manual:cloud');
    expect(repository.records.single.completedReps, 4);
  });
}

class _FakeGateway implements TrainingHistoryGateway {
  final List<TrainingRecord> uploaded = [];
  final List<int> videoHistoryIds = [];
  List<Map<String, dynamic>> cloudRows = [];

  @override
  Future<List<Map<String, dynamic>>> fetchHistory(
          {required int userId}) async =>
      cloudRows;

  @override
  Future<Map<String, dynamic>> uploadMetadata({
    required int userId,
    required TrainingRecord record,
  }) async {
    uploaded.add(record);
    return {'id': 77};
  }

  @override
  Future<void> uploadVideo({
    required int historyId,
    required int userId,
    required String videoPath,
  }) async {
    videoHistoryIds.add(historyId);
  }
}

class _MemoryHistoryRepository implements HistoryRepository {
  _MemoryHistoryRepository(List<TrainingRecord> records)
      : records = List.of(records);

  final List<TrainingRecord> records;

  @override
  Future<void> clearHistory() async => records.clear();

  @override
  Future<List<TrainingRecord>> getHistory() async => List.of(records);

  @override
  Future<List<TrainingRecord>> getUnsyncedRecords() async => records
      .where((r) => !r.isSynced || (r.videoPath != null && !r.isVideoSynced))
      .toList();

  @override
  Future<int> mergeRecords(List<TrainingRecord> incoming) async {
    final timestamps = records.map((r) => r.timestamp).toSet();
    final fresh = incoming.where((r) => timestamps.add(r.timestamp)).toList();
    records.addAll(fresh);
    return fresh.length;
  }

  @override
  Future<void> markAsSynced(String timestamp, {int? historyId}) async {
    final index = records.indexWhere((r) => r.timestamp == timestamp);
    records[index] = records[index].copyWithSynced(true, historyId: historyId);
  }

  @override
  Future<void> markVideoAsSynced(String timestamp, {String? videoUrl}) async {
    final index = records.indexWhere((r) => r.timestamp == timestamp);
    records[index] =
        records[index].copyWithVideoSynced(true, remoteVideoUrl: videoUrl);
  }

  @override
  Future<void> removeByTimestamp(String timestamp) async =>
      records.removeWhere((r) => r.timestamp == timestamp);

  @override
  Future<void> saveRecord(TrainingRecord record) async => records.add(record);

  @override
  Future<void> updateLastRecordsVideoPath(int count, String? videoPath) async {}
}
