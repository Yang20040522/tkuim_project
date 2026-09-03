// lib/features/training/action_tips_dialog.dart
//
// 動作說明彈窗：3D 播放前自動彈一次，點任意處消失。
// 內容依「動作 + 難度 label」對照，沒填的組合就不彈。
// 維護只需改下面的 kActionTips 對照表。

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
///
/// 填法範例（把註解拿掉照填）：
/// ActionType.turnPalm: {
///   'Level 1': ActionTips(points: [
///     '手肘貼緊身體,固定不動',
///     '緩慢翻轉手掌,感受前臂旋轉',
///   ]),
///   'Level 2': ActionTips(points: [
///     '翻轉幅度要更完整',
///     '速度放慢,不要甩',
///   ]),
/// },
const Map<ActionType, Map<String, ActionTips>> kActionTips = {
  ActionType.turnPalm: {
    'Level 1': ActionTips(points: [
      '手肘貼緊身體,保持固定不動',
      '緩慢翻轉手掌,感受前臂的旋轉',
      '每次翻到底停留約 1 秒再翻回',
      '過程中肩膀放鬆,不要聳肩',
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