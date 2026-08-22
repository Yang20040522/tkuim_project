// lib/actions/base_rehab_action.dart

import '../services/mediapipe_service.dart';
import 'rehab_action_callback.dart';

abstract class BaseRehabAction {
  final RehabActionCallback callback;

  BaseRehabAction(this.callback);

  /// 每幀 landmark 進來時觸發，各動作自行處理
  void processLandmarks(List<Landmark> landmarks);

  /// trainingStream 是否可接收
  /// 翻掌要等倒數完才 true；側捏直接 true
  bool get isReadyToReceiveUpdates;

  /// 初始化完成後顯示的提示
  String get initialFeedback;
  String get initialInstruction;

  /// 釋放資源（Timer 等），子類別視需要 override
  void dispose() {}
}

// 🆕 2026-08-22:
//   手部動作的「自動／手動升級」標記介面。
//   只有支援分級的手部動作(側捏、翻掌)才會 implements 這個,
//   翹手腕/左右彎手腕只有單一難度、沒有升級概念,維持原樣不用實作。
//   RehabSessionController/UI 用 `action is HandLevelUpControllable`
//   判斷是否要顯示「等待升級確認」的 UI。
abstract class HandLevelUpControllable {
  // 目前是否卡在「達標、等使用者確認要不要升級」的狀態
  bool get isPendingLevelUp;

  // 卡住的當下,是否還有下一階可以升級(已經是最高難度時為 false)
  bool get hasNextLevel;

  // 下一階的顯示名稱(沒有下一階時可為空字串)
  String get nextLevelLabel;

  // 使用者選「挑戰下一階」時呼叫
  void confirmLevelUp({int? customTargetReps});

  // 使用者選「不要,結束訓練」時呼叫
  void declineLevelUp();
}