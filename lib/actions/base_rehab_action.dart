// lib/actions/base_rehab_action.dart

import '../services/mediapipe_service.dart';
import 'rehab_action_callback.dart';

abstract class BaseRehabAction {
  final RehabActionCallback callback;

  BaseRehabAction(this.callback);

  /// 每幀 landmark 進來時觸發，各動作自行處理。
  void processLandmarks(
    List<Landmark> landmarks,
  );

  /// trainingStream 是否可接收。
  bool get isReadyToReceiveUpdates;

  /// 初始化完成後顯示的提示。
  String get initialFeedback;

  String get initialInstruction;

  /// 目前「這一個難度」累積的錯誤。
  ///
  /// 預設沒有錯誤資料的動作回傳空陣列。
  ///
  /// 有自己維護 _mistakeLogs 的 Action 必須 override。
  List<String> get currentMistakeLogs => const <String>[];

  /// 釋放 Timer 等資源。
  void dispose() {}
}

/// 支援難度升級的動作實作這個介面。
abstract class LevelUpControllable {
  bool get isPendingLevelUp;

  void confirmLevelUp({
    int? customTargetReps,
  });

  void declineLevelUp();
}
