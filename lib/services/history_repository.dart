// lib/services/history_repository.dart
//
// 訓練紀錄的資料存取層(跟 lib/features/plan/plan_repository.dart 同一套模式)。
//
// HistoryService(ChangeNotifier)負責「通知畫面更新」,
// 實際「資料存在哪裡、怎麼存」交給這裡的 HistoryRepository 決定。
//
// 目前上傳到雲端的邏輯是走 exercise_api_service.dart(ExerciseApiService),
// 跟這裡的 HistoryRepository 抽象介面無關;這裡負責的是「紀錄本身」
// 存在本機的存取方式(新增/刪除/更新/查詢待同步紀錄)。
//
// 🆕 2026-08-31:新增 getUnsyncedRecords() / markAsSynced()。
//    配合方案A(訓練結束後才上傳):訓練時手機連樹莓派熱點沒有對外網路,
//    資料先存本機並標記 isSynced=false,使用者在歷史紀錄畫面手動按
//    「上傳到雲端」時,才呼叫 getUnsyncedRecords() 抓出所有還沒上傳的
//    紀錄,一筆一筆送到後端,成功後呼叫 markAsSynced() 標記完成。

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/training_action.dart';

abstract class HistoryRepository {
  Future<List<TrainingRecord>> getHistory();
  Future<void> saveRecord(TrainingRecord record);

  /// 把「最後 count 筆」紀錄的 videoPath 更新成同一個值。
  Future<void> updateLastRecordsVideoPath(int count, String? videoPath);

  Future<void> removeByTimestamp(String timestamp);
  Future<void> clearHistory();

  /// 🆕 取得所有尚未上傳到後端(isSynced == false)的紀錄。
  Future<List<TrainingRecord>> getUnsyncedRecords();

  /// 🆕 把指定 timestamp 的那一筆紀錄標記為「已上傳」(isSynced = true)。
  Future<void> markAsSynced(String timestamp);
}

/// ============ 本地 SharedPreferences 儲存 ============
class LocalHistoryRepository implements HistoryRepository {
  static const String _key = 'rehab_history';

  @override
  Future<List<TrainingRecord>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key) ?? '[]';
    final List<dynamic> list = jsonDecode(jsonStr);
    return list.map((e) => TrainingRecord.fromJson(e)).toList();
  }

  @override
  Future<void> saveRecord(TrainingRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    history.add(record);
    await prefs.setString(
        _key, jsonEncode(history.map((e) => e.toJson()).toList()));
  }

  @override
  Future<void> updateLastRecordsVideoPath(
      int count, String? videoPath) async {
    if (count <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    if (history.isEmpty) return;

    final updateCount = count > history.length ? history.length : count;
    final startIndex = history.length - updateCount;

    for (int i = startIndex; i < history.length; i++) {
      history[i] = history[i].copyWithVideoPath(videoPath);
    }

    await prefs.setString(
        _key, jsonEncode(history.map((e) => e.toJson()).toList()));
  }

  @override
  Future<void> removeByTimestamp(String timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    history.removeWhere((r) => r.timestamp == timestamp);
    await prefs.setString(
        _key, jsonEncode(history.map((e) => e.toJson()).toList()));
  }

  @override
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // 🆕 ─────────────────────────────────────────────────────────

  @override
  Future<List<TrainingRecord>> getUnsyncedRecords() async {
    final history = await getHistory();
    return history.where((r) => !r.isSynced).toList();
  }

  @override
  Future<void> markAsSynced(String timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    final index = history.indexWhere((r) => r.timestamp == timestamp);
    if (index == -1) return; // 找不到這筆,可能已經被刪除了,直接跳過

    history[index] = history[index].copyWithSynced(true);
    await prefs.setString(
        _key, jsonEncode(history.map((e) => e.toJson()).toList()));
  }
}

final HistoryRepository historyRepository = LocalHistoryRepository();