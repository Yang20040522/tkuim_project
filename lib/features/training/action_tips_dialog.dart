// lib/features/training/action_tips_dialog.dart
//
// 動作說明彈窗：3D / 骨架訓練播放前自動彈一次，點任意處消失。
// 內容依「動作 + 難度 label」對照，沒填的組合就不彈。
// 維護只需改下面的 kActionTips 對照表。
//
// 🩺 2026-09-05 治療師實務回饋 — 已整理進 kActionTips：
//   側捏／畫圓／伸手舉高／雙手抬舉／手肘屈伸／翹手腕／左右彎手腕／
//   坐站訓練／側跨步／站姿抬腳，內容盡量貼近生活情境（夾提袋手把、
//   抽衛生紙、貼耳朵、拿東西…），並依現有程式碼的角度/秒數門檻分階撰寫。
//
//   ⚠️ 對照 models/training_action.dart 後確認：`ActionType.wipeBody`
//   這個 enum 名稱雖然字面是「擦拭」，但 kTrainingActions 裡它實際對應
//   的 name 是「站姿抬腳式訓練」，底層邏輯是 standing_knee_raise_action.dart。
//   名稱取得不好、之後有空可以考慮重新命名成 standingKneeRaise 之類的，
//   但改 enum 名稱牽動的地方較多，這次先不動，維持用 wipeBody 這個 key，
//   底下內容填站姿抬腳式的內容。
//
//   下列幾點屬於「產品功能決策」而非單純文字提示，先用註解記錄，
//   等確認後再實作：
//   1. 翻掌(turnPalm)的 3D 示範畫面：治療師希望鏡頭只放大手部、不用
//      拍到半身，畫面越單純越好，並特別凸顯大拇指與小指的位置。這是
//      3D 模型/鏡頭設定的需求，不是彈窗文字，麻煩轉給負責 3D 播放的
//      同事一起看。
//   2. 坐站訓練(sitToStand)：治療師希望之後能新增「半身版」——坐著
//      做上半身前傾/後仰的簡化版本，只需掃描上半身，適合下肢還無法
//      練全身蹲站的使用者；現有全身版(蹲下/站起判定)維持不變，兩個
//      版本並存。此功能尚未實作，目前 kActionTips 內容僅描述現有全身版。
//   3. 側跨步(lateralStep)：治療師提到「兩種模式的訓練」，目前程式碼
//      是自動偵測跨出的那隻腳，沒有像站姿抬腳式(wipeBody/StandingKneeRaiseAction)
//      那樣讓使用者「指定要練哪一腳(患側)」的選項。建議之後可以加上
//      selectLeftLeg() / selectRightLeg() 這類方法，讓自動偵測與指定
//      患側兩種模式並存。

import 'package:flutter/material.dart';
import '../../models/training_action.dart';

/// 一個動作說明的內容
class ActionTips {
  final String title;        // 彈窗標題（留空會用「動作名 · 動作說明」）
  final List<String> points; // 注意事項 / 動作細節，一條一點

  const ActionTips({
    this.title = '',
    required this.points,
  });
}

/// 動作 + 難度 label → 說明的對照表
/// 外層 key：ActionType
/// 內層 key：難度的 label 字串（就是 DifficultyOption.label，像 'Level 1'、'初級'、'中級'）
/// 沒列在這裡的動作 / 難度 = 沒有說明，不彈窗
const Map<ActionType, Map<String, ActionTips>> kActionTips = {
  // ── 翻掌 ─────────────────────────────────────────────
  ActionType.turnPalm: {
    'Level 1': ActionTips(points: [
      '手肘貼緊身體,保持固定不動',
      '緩慢翻轉手掌,感受前臂的旋轉',
      '每次翻到底停留約 1 秒再翻回',
      '過程中肩膀放鬆,不要聳肩',
    ]),
    'Level 2': ActionTips(points: [
      '翻轉幅度要比初階更完整,盡量翻到底',
      '特別留意大拇指與小指的位置變化',
      '手肘一樣要貼緊身體,不要抬起或往外移',
      '速度放慢,感受前臂旋轉,不要用甩的',
    ]),
  },

  // ── 側捏 ─────────────────────────────────────────────
  ActionType.sidePinch: {
    'Level 1': ActionTips(points: [
      '手指微幅開合即可,不用太用力捏',
      '可以想像輕輕夾住提袋手把的感覺',
      '速度放慢,感受大拇指與食指側邊的接觸',
    ]),
    'Level 2': ActionTips(points: [
      '捏合幅度加大,確實捏緊再放開',
      '練習時可以想像抽衛生紙、捏緊提袋手把等生活動作',
      '手腕盡量保持穩定,不要跟著晃動',
    ]),
    'Level 3': ActionTips(points: [
      '手腕懸空不要靠著桌面,減少代償',
      '捏放速度要流暢,不要忽快忽慢',
      '可以想像連續抽取好幾張衛生紙的節奏感',
    ]),
  },

  // ── 站姿抬腳式(enum 名稱是 wipeBody,實際動作是站姿抬腳,見上方註解說明) ──
  ActionType.wipeBody: {
    '初級': ActionTips(points: [
      '訓練前請先選擇要訓練的腳(左腳/右腳),建議選患側腳練習',
      '支撐腳(站立那隻腳)要打直站穩,可以先扶著椅背或牆壁',
      '抬腳幅度只要膝蓋略高於臀部即可,腳掌盡量放平',
    ]),
    '中級': ActionTips(points: [
      '抬腳到接近水平(大腿與地面平行),膝蓋自然彎曲',
      '支撐腳持續打直站穩,身體不要歪斜或後仰',
      '若已經比較穩定,可以嘗試放開扶手,練習單腳站立的平衡',
    ]),
    '高級': ActionTips(points: [
      '抬腳角度更高,精準控制髖關節彎曲角度,並定格 2 秒',
      '支撐腳全程站穩打直,身體保持直立不晃動',
      '這個難度接近單腳站立訓練,建議旁邊有人保護或靠近穩固物品',
    ]),
  },

  // ── 畫圓 ─────────────────────────────────────────────
  ActionType.drawCircle: {
    '初級': ActionTips(points: [
      '適合抬手時不太會疼痛的族群,先從小圓開始',
      '手臂微伸直即可,不用刻意伸到最直',
      '上半圓(手舉高於肩膀時)盡量讓大拇指朝上',
    ]),
    '中級': ActionTips(points: [
      '手臂要伸得更直,圓也要畫得更大一點',
      '感受手肘打直、肩膀放鬆的畫圓軌跡',
      '上半圓大拇指持續朝上,下半圓自然放鬆即可',
    ]),
    '高級': ActionTips(points: [
      '半徑要求最高,手臂全程盡量打直',
      '維持穩定速度,不要忽快忽慢',
      '上半圓大拇指朝上要更注意,避免肩膀內轉代償',
    ]),
  },

  // ── 伸手舉高 ─────────────────────────────────────────
  ActionType.reach: {
    '初級': ActionTips(points: [
      '練習前請先選擇要訓練的手,建議先從單手開始',
      '目標只要舉到水平即可,像伸手去拿旁邊桌上的東西',
      '身體保持挺直,不要往後仰借力',
    ]),
    '中級': ActionTips(points: [
      '目標舉高到接近頭頂,像是要摸到自己的耳朵旁邊',
      '舉到最高點後慢慢放下,感受手臂的控制力',
      '一樣不要後仰,不要借用身體晃動代償',
    ]),
    '高級': ActionTips(points: [
      '舉到頭頂後要撐住 3 秒,像拿高處物品時穩住手臂',
      '過程中如果手掉下來太多,需重新舉高撐穩',
      '放下速度也要放慢,不要用甩的',
    ]),
  },

  // ── 雙手抬舉式 ───────────────────────────────────────
  ActionType.raiseBothArms: {
    '初級': ActionTips(points: [
      '好手交扣帶著患側手,患側手也要主動一起出力,不是完全被拉著動',
      '這是入門動作,雙手一起抬舉會比單手動作更容易上手',
      '只需抬到水平即可,速度放慢',
    ]),
    '中級': ActionTips(points: [
      '舉高到接近頭頂,撐住 2 秒再放下',
      '抬到最高點時記得大拇指朝上,避免肩膀內轉代償',
      '雙手盡量同步,不要好手衝太快、丟下患側手',
    ]),
    '高級': ActionTips(points: [
      '舉超過頭頂並撐住 3 秒',
      '全程留意聳肩、後仰等代償動作,保持坐正、肩膀放鬆',
      '放下也要慢慢控制,不要一放手就掉下來',
    ]),
  },

  // ── 手肘屈伸 ─────────────────────────────────────────
  ActionType.elbowForward: {
    '初級': ActionTips(points: [
      '手肘的部分建議先躺著訓練比較容易上手,雙手往天花板方向伸直',
      '十指交扣,手肘從彎到直,慢慢重複',
      '坐姿訓練比較貼近生活情境,若躺姿較穩定可以先從躺姿開始',
    ]),
    '中級': ActionTips(points: [
      '伸直後撐住 2 秒,感受手肘完全伸展',
      '雙手速度盡量一致,患側手不要落後',
      '躺姿或坐姿都可以,依個人穩定度選擇',
    ]),
    '高級': ActionTips(points: [
      '伸直撐住 3 秒,可嘗試讓患側手在空中畫小圈圈增加控制挑戰',
      '全程雙手一起動作,避免只有好手用力',
      '坐姿訓練更貼近日常生活動作,穩定後可以挑戰坐姿版本',
    ]),
  },

  // ── 翹手腕(往上翹/往下壓) ───────────────────────────
  ActionType.wristExtension: {
    'Level 1': ActionTips(points: [
      '空手練習,手腕交替往上翹(像跟天空打招呼)和往下壓',
      '手肘固定放在桌上不動,只有手腕在動',
      '速度放慢,感受背屈與掌屈的差別',
    ]),
    'Level 2': ActionTips(points: [
      '進階改成手握水壺(或類似重量的物品)增加阻力,動作幅度要求更大',
      '上翹幅度盡量加大,像用力把手背往上抬',
      '下壓與上翹之間的節奏要穩定,不要忽快忽慢,拿重物時更要控制好速度',
    ]),
  },

  // ── 左右彎手腕 ───────────────────────────────────────
  ActionType.wristSideBend: {
    '標準': ActionTips(points: [
      '雙手手指交扣,健側手帶領患側手腕左右彎曲',
      '往左彎到底停留 1 秒,再往右彎到底停留 1 秒,算一次',
      '想像手腕像雨刷一樣左右穩定擺動,不要用甩的',
    ]),
  },

  // ── 坐站訓練 ─────────────────────────────────────────
  // 🩺 現階段內容對應「全身版」(蹲下/站起判定)。
  //   治療師建議之後補一個「半身版」(坐著前傾/後仰,只需掃描上半身)，
  //   詳見檔案頂端的功能決策說明。
  ActionType.sitToStand: {
    '初級': ActionTips(points: [
      '微蹲即可,重心放在腳跟,慢慢坐下再站起來',
      '若使用輪椅或穩固椅子,請先確認椅子已鎖定、位置安全',
      '膝蓋不要往內夾,盡量保持與肩同寬',
    ]),
    '中級': ActionTips(points: [
      '蹲得更深一點,感受大腿更多發力',
      '站起與坐下的速度都要放慢,控制好每個階段',
      '全程留意膝蓋方向,避免內夾代償',
    ]),
    '高級': ActionTips(points: [
      '蹲到最深且撐住 3 秒,再慢慢站起',
      '特別留意坐下前的重心轉移,慢慢靠近椅面再坐下,確保安全',
      '這個動作牽涉較多重心控制細節,建議旁邊有人陪同或扶穩再嘗試',
    ]),
  },

  // ── 側跨步 ───────────────────────────────────────────
  ActionType.lateralStep: {
    '初級': ActionTips(points: [
      '跨出一小步就好,能穩定完成就很棒了',
      '剛開始不穩,可以先用好手扶著穩固的物品或家具',
      '練習患側腳跨出,支撐腳(留在原地那隻)盡量保持伸直',
    ]),
    '中級': ActionTips(points: [
      '跨步幅度可以再大一點,蹲的深度也增加',
      '支撐腳保持穩定,不要跟著彎曲',
      '扶著東西的手可以慢慢減少施力,練習自己平衡',
    ]),
    '高級': ActionTips(points: [
      '目標至少能連續橫移幾步,蹲得更深也撐得住',
      '盡量不扶東西,靠自己控制重心與平衡',
      '支撐腳全程打直,感受單側肌力與平衡的挑戰',
    ]),
  },

};

/// 查某動作某難度有沒有說明（沒有回 null）
ActionTips? getActionTips(ActionType type, String difficultyLabel) {
  return kActionTips[type]?[difficultyLabel];
}

/// 顯示說明彈窗（點任意處消失）
void showActionTipsDialog(
  BuildContext context, {
  required String actionName,
  required ActionTips tips,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => GestureDetector(
      onTap: () => Navigator.of(ctx).pop(), // 點卡片外關閉
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: GestureDetector(
          onTap: () {}, // 點卡片本身不關（避免誤觸）
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 標題列
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.lightbulb_outline,
                          color: Color(0xFFF59E0B), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tips.title.isNotEmpty
                            ? tips.title
                            : '$actionName · 動作說明',
                        style: const TextStyle(
                          color: Color(0xFF1A1D2E),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 說明條列
                ...tips.points.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4A65FF),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              p,
                              style: const TextStyle(
                                color: Color(0xFF374151),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),

                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '點任意處關閉',
                    style: TextStyle(
                      color: const Color(0xFF9CA3AF).withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}