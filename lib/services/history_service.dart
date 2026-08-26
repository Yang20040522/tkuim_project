import '../models/training_action.dart';
import '../features/notification/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'history_repository.dart';

/// 對畫面來說,HistoryService 的用法完全沒變(一樣是 ChangeNotifier,
/// 一樣用 HistoryService() 建立,一樣呼叫 getHistory()/saveRecord() 等)。
///
/// 差別只在於:實際資料存在哪裡、怎麼存,現在都交給 historyRepository
/// (定義在 history_repository.dart)決定。本地儲存 / 之後接後端 API,
/// 只需要在 history_repository.dart 最下面切換一行,這裡完全不用改。
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
}