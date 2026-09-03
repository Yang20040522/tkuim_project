import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_body/features/home/home_screen.dart';
import 'package:flutter_body/features/stats/personal_records_card.dart';
import 'package:flutter_body/features/stats/stats_screen.dart';
import 'package:flutter_body/models/training_action.dart';
import 'package:flutter_body/services/history_repository.dart';
import 'package:flutter_body/services/history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('default HistoryService instances share change notifications', () async {
    final listenerSide = HistoryService();
    final writerSide = HistoryService();
    var notificationCount = 0;
    void listener() => notificationCount++;

    expect(identical(listenerSide, writerSide), isTrue);
    listenerSide.addListener(listener);
    await writerSide.updateLastRecordsVideoPath(0, null);
    listenerSide.removeListener(listener);

    expect(notificationCount, 1);
  });

  testWidgets('Home loads once initially and ordinary rebuilds do not reload',
      (tester) async {
    final repository = _CountingHistoryRepository([_record(1)]);
    final service = HistoryService.withRepository(repository);

    await tester.pumpWidget(_testApp(service, const HomeScreen()));
    await tester.pumpAndSettle();

    // PageView initially builds Home only. Stats performs its own initial load
    // when the user first visits that page.
    expect(repository.getHistoryCalls, 1);
    expect(find.text('100 %'), findsWidgets);

    await tester.pumpWidget(_testApp(service, const HomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(repository.getHistoryCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });

  testWidgets('Stats reload only after a real history change', (tester) async {
    final repository = _CountingHistoryRepository([_record(1)]);
    final service = HistoryService.withRepository(repository);

    await tester.pumpWidget(_testApp(service, const StatsScreen()));
    await tester.pumpAndSettle();

    expect(repository.getHistoryCalls, 5);

    await tester.pumpWidget(_testApp(service, const StatsScreen()));
    await tester.pump();
    expect(repository.getHistoryCalls, 5);

    await service.saveRecord(_record(2));
    await tester.pumpAndSettle();

    expect(repository.getHistoryCalls, 10);
    expect(find.text('2 組'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });

  testWidgets('Async load completion after dispose does not call setState',
      (tester) async {
    final pendingHistory = Completer<List<TrainingRecord>>();
    final repository = _CountingHistoryRepository(
      const [],
      pendingHistory: pendingHistory,
    );
    final service = HistoryService.withRepository(repository);

    await tester.pumpWidget(_testApp(service, const PersonalRecordsCard()));
    expect(repository.getHistoryCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    pendingHistory.complete([_record(1)]);
    await tester.pump();

    expect(tester.takeException(), isNull);
    service.dispose();
  });
}

Widget _testApp(HistoryService service, Widget home) {
  return ChangeNotifierProvider<HistoryService>.value(
    value: service,
    child: MaterialApp(home: home),
  );
}

TrainingRecord _record(int sequence) {
  return TrainingRecord(
    timestamp:
        DateTime.now().add(Duration(seconds: sequence)).toIso8601String(),
    actionName: '測試動作',
    difficulty: 1,
    durationSeconds: 60,
    mistakeLogs: const [],
    targetReps: 10,
  );
}

class _CountingHistoryRepository implements HistoryRepository {
  _CountingHistoryRepository(
    List<TrainingRecord> records, {
    this.pendingHistory,
  }) : records = List.of(records);

  final List<TrainingRecord> records;
  final Completer<List<TrainingRecord>>? pendingHistory;
  int getHistoryCalls = 0;

  @override
  Future<List<TrainingRecord>> getHistory() {
    getHistoryCalls++;
    final pending = pendingHistory;
    if (pending != null) return pending.future;
    return Future.value(List.of(records));
  }

  @override
  Future<void> saveRecord(TrainingRecord record) async {
    records.add(record);
  }

  @override
  Future<void> updateLastRecordsVideoPath(
    int count,
    String? videoPath,
  ) async {
    final start = (records.length - count).clamp(0, records.length);
    for (var index = start; index < records.length; index++) {
      records[index] = records[index].copyWithVideoPath(videoPath);
    }
  }

  @override
  Future<void> removeByTimestamp(String timestamp) async {
    records.removeWhere((record) => record.timestamp == timestamp);
  }

  @override
  Future<void> clearHistory() async {
    records.clear();
  }

  @override
  Future<List<TrainingRecord>> getUnsyncedRecords() async {
    return records.where((record) => !record.isSynced).toList();
  }

  @override
  Future<void> markAsSynced(String timestamp) async {
    final index = records.indexWhere((record) => record.timestamp == timestamp);
    if (index >= 0) {
      records[index] = records[index].copyWithSynced(true);
    }
  }
}
