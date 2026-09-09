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
import 'exercise_api_service.dart'; // 🆕 治療師唯讀遠端 repository 用

abstract class HistoryRepository {
  Future<List<TrainingRecord>> getHistory();
  Future<void> saveRecord(TrainingRecord record);

  /// 把「最後 count 筆」紀錄的 videoPath 更新成同一個值。
  Future<void> updateLastRecordsVideoPath(int count, String? videoPath);

  Future<void> removeByTimestamp(String timestamp);
  Future<void> clearHistory();

  /// 取得 metadata 尚未同步，或仍有本機影片待補傳的紀錄。
  Future<List<TrainingRecord>> getUnsyncedRecords();

  /// metadata 上傳成功後保存後端 id，影片狀態不受影響。
  Future<void> markAsSynced(String timestamp, {int? historyId});

  /// 本機影片成功上傳後標記，讓 metadata 成功／影片失敗可以分開重試。
  Future<void> markVideoAsSynced(
    String timestamp, {
    String? videoUrl,
  });

  /// 🆕 把一批紀錄合併進儲存空間,timestamp 已存在的略過,回傳實際新增筆數。
  ///    給「病患從雲端把自己的紀錄拉回本機」用(換手機/重裝後救回)。
  Future<int> mergeRecords(List<TrainingRecord> incoming);
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
    return history
        .where((r) => !r.isSynced || (r.videoPath != null && !r.isVideoSynced))
        .toList();
  }

  @override
  Future<void> markAsSynced(String timestamp, {int? historyId}) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    final index = history.indexWhere((r) => r.timestamp == timestamp);
    if (index == -1) return; // 找不到這筆,可能已經被刪除了,直接跳過

    history[index] = history[index].copyWithSynced(true, historyId: historyId);
    await prefs.setString(
        _key, jsonEncode(history.map((e) => e.toJson()).toList()));
  }

  @override
  Future<void> markVideoAsSynced(
    String timestamp, {
    String? videoUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    final index = history.indexWhere((r) => r.timestamp == timestamp);
    if (index == -1) return;

    history[index] = history[index].copyWithVideoSynced(
      true,
      remoteVideoUrl: videoUrl,
    );
    await prefs.setString(
        _key, jsonEncode(history.map((e) => e.toJson()).toList()));
  }

  @override
  Future<int> mergeRecords(List<TrainingRecord> incoming) async {
    if (incoming.isEmpty) return 0;
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    final existing = history.map((r) => r.timestamp).toSet();

    int added = 0;
    for (final record in incoming) {
      if (!existing.contains(record.timestamp)) {
        history.add(record);
        existing.add(record.timestamp);
        added++;
      }
    }

    if (added > 0) {
      await prefs.setString(
          _key, jsonEncode(history.map((e) => e.toJson()).toList()));
    }
    return added;
  }
}

final HistoryRepository historyRepository = LocalHistoryRepository();

/// ============ 唯讀遠端儲存(治療師看指定病患用) ============
///
/// 只從後端 GET /api/training-history/{userId} 讀某個病患的紀錄,
/// 不寫入任何東西(治療師不應該改病患的紀錄)。第一次讀取後會快取,
/// 所以就算數據頁上有多張卡片各自呼叫 getHistory(),也只打一次網路。
class RemoteHistoryRepository implements HistoryRepository {
  RemoteHistoryRepository({
    required this.userId,
    this.viewerUserId,
    this.identityToken,
  });

  /// 要查看的病患的使用者 id。
  final int userId;
  final int? viewerUserId;
  final String? identityToken;

  List<TrainingRecord>? _cache;

  @override
  Future<List<TrainingRecord>> getHistory() async {
    final cached = _cache;
    if (cached != null) return cached;

    final rows = await ExerciseApiService.fetchTrainingHistory(
      userId: userId,
      requesterUserId: viewerUserId,
      identityToken: identityToken,
    );
    final records = rows.map((e) => TrainingRecord.fromJson(e)).toList();
    _cache = records;
    return records;
  }

  // ↓ 以下都是唯讀:治療師端不該改病患紀錄,呼叫到就明確報錯。
  @override
  Future<void> saveRecord(TrainingRecord record) =>
      throw UnsupportedError('唯讀:治療師端不能新增病患紀錄');

  @override
  Future<void> updateLastRecordsVideoPath(int count, String? videoPath) =>
      throw UnsupportedError('唯讀:治療師端不能修改病患紀錄');

  @override
  Future<void> removeByTimestamp(String timestamp) =>
      throw UnsupportedError('唯讀:治療師端不能刪除病患紀錄');

  @override
  Future<void> clearHistory() =>
      throw UnsupportedError('唯讀:治療師端不能清除病患紀錄');

  @override
  Future<List<TrainingRecord>> getUnsyncedRecords() async => const [];

  @override
  Future<void> markAsSynced(String timestamp, {int? historyId}) async {}

  @override
  Future<void> markVideoAsSynced(
    String timestamp, {
    String? videoUrl,
  }) async {}

  @override
  Future<int> mergeRecords(List<TrainingRecord> incoming) =>
      throw UnsupportedError('唯讀:治療師端不能寫入病患紀錄');
}
