// lib/actions/body_rehab_action.dart
//
// 全身復健動作的「合約」。
// 所有全身復健動作都 implements 這個,共用畫面殼才認得它們。

import '../models/body_frame.dart';

// 動作每幀判定後,回報給畫面的結果
class RehabFeedback {
  final String? prompt;   // 要顯示的提示文字 (null = 無變化)
  final bool scored;      // 這幀是否完成一次計數
  final bool leveledUp;   // 這幀是否升級難度

  const RehabFeedback({
    this.prompt,
    this.scored = false,
    this.leveledUp = false,
  });

  static const none = RehabFeedback();
}

// 全身復健動作合約
abstract class BodyRehabAction {
  // 畫面標題
  String get title;

  // 開始時的提示語
  String get initialHint;

  // 目前難度顯示文字 (例:初級/中級/高級)
  String get difficultyLabel;

  // 畫面每幀餵骨架進來,動作回報判定結果
  RehabFeedback update(BodyFrame frame);
}

abstract class LevelUpControllable {
  bool get isPendingLevelUp;
  void confirmLevelUp({int? customTargetReps});
  void declineLevelUp();
}

// 復健難度三階(全身共用)
enum RehabDifficulty { easy, medium, hard }

// 🆕 2026-09-06 治療師回饋:
//   側跨步、站姿抬腳式建議提供「簡單版/困難版」兩種練習模式:
//     - moveTrainedLeg      (簡單版):患側腳負責動(抬起/跨出),好腳負責撐。
//     - supportOnTrainedLeg (困難版):反過來,患側腳負責撐(單腳承重站穩),
//       好腳負責動。困難版的偵測邏輯不一樣 —— 重點從「動作有沒有做到位」
//       變成「支撐腳(患側)有沒有站穩、有沒有晃動」,是額外的平衡挑戰。
//   這個模式跟原本的 RehabDifficulty(角度深度三階)是兩個獨立的維度,
//   兩者互相搭配使用(先選簡單版或困難版,裡面一樣有初/中/高可以練)。
//
//   實作這個模式的動作(standingKneeRaise、lateralStep)都遵循同一套 API:
//     selectTrainedLeg(isLeft: true/false)  → 標記患側是左腳還是右腳
//     selectSupportLeg(isLeft: true/false)  → 直接選哪隻腳當支撐腳,
//                                              另一隻腳自動變成要動的腳
//   role(簡單版/困難版)是比對「支撐腳選的是不是患側」算出來的結果,
//   不是額外選的選項；兩個選腳動作都做了(legAndModeSelected == true)
//   才會開始偵測,跟 reach_action 選手的流程一致。
enum TrainingLegRole { moveTrainedLeg, supportOnTrainedLeg }

// 🆕 2026-09-06:讓 body_training_screen 可以用同一套 UI 邏輯,處理任何
//    「需要選患側 + 簡單/困難版」的下肢動作(standing_knee_raise、
//    lateral_step 都實作這個)。畫面只認這個介面,不需要知道底下是
//    哪一個動作類別,寫法比照 ReachAction 的「選手」流程。
abstract class LegRoleSelectable {
  /// 第一步(選患側)是否已完成
  bool get trainedLegSelected;

  /// 兩步驟(選患側 + 選模式)是否都完成,完成才會開始偵測
  bool get legAndModeSelected;

  /// 第一步:選患側是左腳(true)還是右腳(false)
  void selectTrainedLeg({required bool isLeft});

  /// 第二步 · 簡單版:患側負責動,好腳負責撐
  void selectSimpleMode();

  /// 第二步 · 困難版:患側負責撐,好腳負責動
  void selectHardMode();

  /// 目前算出來的模式(給畫面判斷要不要顯示困難版專屬提示用)
  TrainingLegRole get role;

  /// 簡單版/困難版顯示文字
  String get roleLabel;
}