// lib/services/history_service.dart
//
// 對畫面來說,HistoryService 的用法完全沒變(一樣是 ChangeNotifier,
// 一樣用 HistoryService() 建立,一樣呼叫 getHistory()/saveRecord() 等)。
//
// 差別只在於:實際資料存在哪裡、怎麼存,現在都交給 historyRepository
// (定義在 history_repository.dart)決定。本地儲存 / 之後接後端 API,
// 只需要在 history_repository.dart 最下面切換一行,這裡完全不用改。
//
// 🆕 2026-08-31:新增 uploadPendingRecords()。
//    配合方案A(訓練結束後才上傳):訓練時手機連樹莓派熱點,沒有對外網路,
//    紀錄先存在本機(isSynced=false)。使用者回到有網路的環境後,在歷史
//    紀錄畫面按「上傳到雲端」按鈕,呼叫這個方法,把所有尚未上傳的紀錄
//    送到後端(ExerciseApiService),成功的標記為已同步,失敗的保留原狀
//    以便下次重試。
//
// 🆕 2026-08-31(第二次更新):新增 uploadSingleRecord()。
//    配合歷史紀錄畫面上「每張卡片自己的上傳按鈕」,讓使用者可以自己
//    挑選要上傳哪一筆,而不是每次都整批上傳所有待同步紀錄。
//    內部直接重用 _uploadSingleRecord() 這個私有方法,跟整批上傳
//    共用同一套「轉換欄位 → 呼叫後端 → 標記同步」邏輯,避免邏輯重複。
//
//    上傳目標:後端 POST /api/training-history(專為自由訓練紀錄新增的表),
//    欄位直接對齊 TrainingRecord,不需要 exerciseId 對照表,difficulty /
//    durationSeconds / targetReps / mistakeLogs 都會完整存進資料庫。
//    userId 由呼叫端(UI)提供,目前來源是登入者 AppSession.userId。
//    唯一沒上傳的是 videoPath(手機本機路徑,治療師端開不了)。
//
// 🆕 syncFromCloud():病患從雲端把自己的紀錄拉回本機(換手機/重裝後救回)。
//    因為數據頁的卡片都聽這個 ChangeNotifier,同步完會自動重算顯示。

import '../models/training_action.dart';
import '../features/notification/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'history_repository.dart';
import 'exercise_api_service.dart'; // 🆕 後端提供的上傳 API

/// 上傳完成後的結果統計,方便畫面顯示「成功 N 筆、失敗 N 筆」。
class UploadResult {
  final int success;
  final int failed;
  final int total;

  const UploadResult({
    required this.success,
    required this.failed,
    required this.total,
  });

  bool get allSucceeded => failed == 0 && total > 0;
  bool get hasNothingToUpload => total == 0;
}

class HistoryService extends ChangeNotifier {
  HistoryService._(this._repository);

  static final HistoryService _instance = HistoryService._(historyRepository);

  /// App-wide history notifier. Existing call sites can keep using
  /// `HistoryService()` and still observe writes made from another screen.
  factory HistoryService() => _instance;

  @visibleForTesting
  HistoryService.withRepository(this._repository);

  /// 🆕 給「治療師查看某病患數據」用:注入一個唯讀的遠端 repository,
  /// 產生一個獨立(非單例)的 HistoryService,只讀不寫。
  HistoryService.readOnly(this._repository);

  final HistoryRepository _repository;

  Future<List<TrainingRecord>> getHistory() => _repository.getHistory();

  Future<void> saveRecord(TrainingRecord record) async {
    await _repository.saveRecord(record);

    final mistakes = record.mistakeLogs.length;
    final acc = ((10 - mistakes) / 10 * 100).clamp(0, 100).round();
    NotificationService().addAchievement(
      title: mistakes == 0 ? '完美完成一組訓練 🎯' : '完成一組訓練 ✅',
      body: '「${record.actionName}」${record.targetReps} 下 · 準確度 $acc%',
    ).catchError((_) {});

    notifyListeners();
  }

  /// 把「最後 count 筆」紀錄的 videoPath 更新成同一個值。
  ///
  /// 用途:一次訓練 session 中可能因為升級難度分批存了好幾筆
  /// TrainingRecord(此時還不知道使用者要不要保留錄影),
  /// 等到 session 真正結束、使用者做出保留/不保留的決定後,
  /// 才回頭把這幾筆紀錄的 videoPath 補齊,讓它們共用同一段影片。
  Future<void> updateLastRecordsVideoPath(int count, String? videoPath) async {
    await _repository.updateLastRecordsVideoPath(count, videoPath);
    notifyListeners();
  }

  Future<void> removeByTimestamp(String timestamp) async {
    await _repository.removeByTimestamp(timestamp);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _repository.clearHistory();
    notifyListeners();
  }

  // 🆕 ─────────────────────────────────────────────────────────
  //  上傳到雲端(方案A:手動觸發,非自動偵測網路)
  // ─────────────────────────────────────────────────────────

  /// 取得目前有幾筆紀錄還沒上傳,給 UI 顯示「N 筆待同步」用。
  Future<int> getPendingUploadCount() async {
    final pending = await _repository.getUnsyncedRecords();
    return pending.length;
  }

  /// 把所有尚未上傳(isSynced == false)的紀錄送到後端。
  ///
  /// [userId] 目前登入的使用者/病患 ID,呼叫端(UI)要負責提供,
  /// 這裡不假設任何取得方式,避免跟你們既有的登入邏輯耦合錯誤。
  ///
  /// 逐筆上傳、逐筆標記,某一筆失敗不會擋住其他筆繼續嘗試,
  /// 最後回傳成功/失敗的統計,失敗的紀錄會保留 isSynced=false,
  /// 下次再按上傳時會繼續重試。
  Future<UploadResult> uploadPendingRecords({required int userId}) async {
    final pending = await _repository.getUnsyncedRecords();

    if (pending.isEmpty) {
      return const UploadResult(success: 0, failed: 0, total: 0);
    }

    int success = 0;
    int failed = 0;

    for (final record in pending) {
      try {
        await _uploadSingleRecord(record, userId: userId);
        await _repository.markAsSynced(record.timestamp);
        success++;
      } catch (e) {
        debugPrint('上傳訓練紀錄失敗(${record.timestamp}): $e');
        failed++;
        // 失敗就跳過,保留 isSynced=false,下次按上傳時會再試一次
      }
    }

    notifyListeners();

    return UploadResult(success: success, failed: failed, total: pending.length);
  }

  /// 🆕 上傳「單一筆」紀錄到後端(給歷史紀錄畫面上每張卡片的上傳按鈕用)。
  ///
  /// 跟 uploadPendingRecords() 不同的地方在於:這個方法只處理呼叫端指定
  /// 的那一筆,不會去抓「所有待上傳」的清單,適合使用者自己在畫面上
  /// 挑選要上傳哪一筆的情境。內部直接重用 _uploadSingleRecord(),
  /// 跟整批上傳共用同一套轉換欄位 / 呼叫後端的邏輯。
  ///
  /// 回傳 true 代表這筆上傳成功並已標記為已同步;
  /// 回傳 false 代表上傳失敗,這筆紀錄會保留 isSynced=false,
  /// 呼叫端(UI)可以用回傳值決定要顯示什麼提示訊息。
  Future<bool> uploadSingleRecord(
    TrainingRecord record, {
    required int userId,
  }) async {
    try {
      await _uploadSingleRecord(record, userId: userId);
      await _repository.markAsSynced(record.timestamp);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('上傳單筆訓練紀錄失敗(${record.timestamp}): $e');
      return false;
    }
  }

  /// 🆕 從雲端把這個使用者的紀錄同步下來、合併進本機。
  ///
  /// 給病患「換手機/重裝 app 後把自己的歷史救回來」用:呼叫後端
  /// GET /api/training-history/{userId} 拿到雲端紀錄,用 timestamp 去重
  /// 後合併進本機儲存,回傳實際新增的筆數。因為數據頁的卡片都聽這個
  /// ChangeNotifier,有新增時 notifyListeners() 會讓它們自動重算。
  ///
  /// 需要有網路 + 已登入(userId 由呼叫端提供)。任何一步失敗都會往外丟
  /// Exception,由呼叫端(UI)決定要顯示什麼提示。
  Future<int> syncFromCloud({required int userId}) async {
    final rows = await ExerciseApiService.fetchTrainingHistory(userId: userId);
    final cloud = rows.map((e) => TrainingRecord.fromJson(e)).toList();
    final added = await _repository.mergeRecords(cloud);
    if (added > 0) notifyListeners();
    return added;
  }

  /// 把單筆 TrainingRecord 送到後端 /api/training-history。
  ///
  /// 後端這張表(training_history)是專門為自由訓練紀錄新增的,欄位直接
  /// 對齊 TrainingRecord,所以不需要「動作名稱 → exerciseId」對照表,
  /// difficulty / mistakeLogs / targetReps 也都會完整存進資料庫,
  /// 不像舊的 /api/exercise/result 會遺失欄位。
  ///
  /// 後端用 (userId, clientTimestamp) 做冪等 upsert,所以同一筆重複上傳
  /// 不會在資料庫產生重複列;失敗會往外丟 Exception,由呼叫端決定重試。
  ///
  /// ⚠️ 唯一沒送的是 record.videoPath —— 那是手機本機路徑,傳字串到後端
  /// 治療師也開不了,要真的讓治療師看影片得另外做檔案上傳。
  Future<void> _uploadSingleRecord(
    TrainingRecord record, {
    required int userId,
  }) async {
    await ExerciseApiService.uploadTrainingHistory(
      userId: userId,
      clientTimestamp: record.timestamp,
      actionName: record.actionName,
      difficulty: record.difficulty,
      durationSeconds: record.durationSeconds,
      targetReps: record.targetReps,
      mistakeLogs: record.mistakeLogs,
    );
  }
}