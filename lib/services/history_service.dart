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
//    ⚠️ TODO(欄位對接):目前後端提供的 ExerciseApiService.saveResult()
//    需要的欄位(userId, exerciseId, repCount, accuracy, progress,
//    speedState, isComplete)跟 TrainingRecord 現有欄位(timestamp,
//    actionName, difficulty, durationSeconds, mistakeLogs, videoPath,
//    targetReps)沒有完全對應,尤其是:
//      - exerciseId:需要「動作名稱 → exerciseId」的對照表(尚未建立)
//      - userId:需要串接目前登入使用者的 ID(尚未串接來源)
//      - difficulty / videoPath / mistakeLogs 沒有對應欄位,上傳後
//        這些資訊在後端資料庫裡會遺失,治療師端目前看不到
//    在跟後端確認並補齊這些欄位之前,_uploadSingleRecord() 裡的呼叫
//    先用最合理的方式湊出請求,並在關鍵缺口處用 TODO 標注清楚,
//    避免之後忘記要回頭調整。

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
  Future<List<TrainingRecord>> getHistory() => historyRepository.getHistory();

  Future<void> saveRecord(TrainingRecord record) async {
    await historyRepository.saveRecord(record);

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
    await historyRepository.updateLastRecordsVideoPath(count, videoPath);
    notifyListeners();
  }

  Future<void> removeByTimestamp(String timestamp) async {
    await historyRepository.removeByTimestamp(timestamp);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await historyRepository.clearHistory();
    notifyListeners();
  }

  // 🆕 ─────────────────────────────────────────────────────────
  //  上傳到雲端(方案A:手動觸發,非自動偵測網路)
  // ─────────────────────────────────────────────────────────

  /// 取得目前有幾筆紀錄還沒上傳,給 UI 顯示「N 筆待同步」用。
  Future<int> getPendingUploadCount() async {
    final pending = await historyRepository.getUnsyncedRecords();
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
    final pending = await historyRepository.getUnsyncedRecords();

    if (pending.isEmpty) {
      return const UploadResult(success: 0, failed: 0, total: 0);
    }

    int success = 0;
    int failed = 0;

    for (final record in pending) {
      try {
        await _uploadSingleRecord(record, userId: userId);
        await historyRepository.markAsSynced(record.timestamp);
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
      await historyRepository.markAsSynced(record.timestamp);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('上傳單筆訓練紀錄失敗(${record.timestamp}): $e');
      return false;
    }
  }

  /// 把單筆 TrainingRecord 轉換成後端 API 需要的格式並送出。
  ///
  /// ⚠️ TODO:exerciseId 目前用 0 佔位,需要建立「動作名稱 → exerciseId」
  /// 的對照表(可以呼叫 ExerciseApiService.fetchExercises() 拿到完整
  /// 清單後在本地做名稱比對,或請後端提供更直接的查詢方式)。
  /// 在對照表補上之前,上傳後後端可能無法正確辨識是哪個動作。
  Future<void> _uploadSingleRecord(
    TrainingRecord record, {
    required int userId,
  }) async {
    final perfect =
        (record.targetReps - record.mistakeLogs.length).clamp(0, record.targetReps);
    final accuracy = record.targetReps > 0
        ? perfect / record.targetReps * 100
        : 0.0;

    await ExerciseApiService.saveResult(
      userId: userId,
      exerciseId: 0, // TODO: 換成「actionName → exerciseId」對照表查出來的真正值
      repCount: perfect,
      accuracy: accuracy,
      progress: 1.0, // 訓練已結束,視為完成度 100%
      speedState: 'normal', // TODO: 目前 TrainingRecord 沒有存這個資訊,先給預設值
      isComplete: true,
    );

    // ⚠️ 提醒:record.difficulty / record.videoPath / record.mistakeLogs
    // 目前的 ExerciseApiService.saveResult() 沒有對應欄位可以送,
    // 這幾項資訊上傳後暫時不會出現在後端資料庫裡,治療師端也看不到。
    // 待後端補齊欄位或提供其他端點後,這裡需要一併更新。
  }
}