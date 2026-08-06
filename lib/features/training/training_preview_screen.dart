// lib/features/training/training_preview_screen.dart
//
// 訓練前 3D 示範頁:
// - 顯示該動作的 3D 模型(model_viewer_plus)
// - 有左右切換(如果該動作有多個模型)
// - 「開始訓練」按鈕 → pushReplacement 到實際訓練頁
//
// 只有「有對應 3D 的動作」才會走到這頁;沒有 3D 的動作由入口直接進訓練頁。

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../../models/training_action.dart';

/// 一個動作的 3D 示範資料
class ActionDemo3D {
  final List<String> modelSrcs; // 一或多個 glb(左右手/腳)
  final List<String> tabLabels; // 對應的分頁標籤

  const ActionDemo3D({
    required this.modelSrcs,
    required this.tabLabels,
  });
}

/// ActionType → 3D 示範資料的對照表
/// 沒列在這裡的動作 = 沒有 3D 示範
const Map<ActionType, ActionDemo3D> kActionDemo3DMap = {
  ActionType.reach: ActionDemo3D(
    modelSrcs: [
      'assets/models/turn_Right_hand.glb',
      'assets/models/turn_Left_hand.glb',
    ],
    tabLabels: ['右手', '左手'],
  ),
  ActionType.drawCircle: ActionDemo3D(
    modelSrcs: ['assets/models/arm_circle_right.glb'],
    tabLabels: ['示範'],
  ),
  ActionType.raiseBothArms: ActionDemo3D(
    modelSrcs: ['assets/models/Both_Arms_Arise.glb'],
    tabLabels: ['示範'],
  ),
  ActionType.elbowForward: ActionDemo3D(
    modelSrcs: ['assets/models/elbow_flexion_extension.glb'],
    tabLabels: ['示範'],
  ),
  ActionType.lateralStep: ActionDemo3D(
    modelSrcs: ['assets/models/side_step.glb'],
    tabLabels: ['示範'],
  ),
  ActionType.wipeBody: ActionDemo3D(
    modelSrcs: [
      'assets/models/Standing_Leg_Raise_Right.glb',
      'assets/models/Standing_Leg_Raise_left.glb',
    ],
    tabLabels: ['右腳', '左腳'],
  ),
  ActionType.sitToStand: ActionDemo3D(
    modelSrcs: ['assets/models/squat.glb'],
    tabLabels: ['示範'],
  ),
};

/// 判斷某動作有沒有 3D 示範
bool hasDemo3D(ActionType type) => kActionDemo3DMap.containsKey(type);

class TrainingPreviewScreen extends StatefulWidget {
  final ActionType actionType;
  final String actionName;
  final Widget targetScreen; // 按「開始」後要進入的實際訓練頁

  const TrainingPreviewScreen({
    super.key,
    required this.actionType,
    required this.actionName,
    required this.targetScreen,
  });

  @override
  State<TrainingPreviewScreen> createState() => _TrainingPreviewScreenState();
}

class _TrainingPreviewScreenState extends State<TrainingPreviewScreen> {
  int _currentTab = 0;

  ActionDemo3D get _demo => kActionDemo3DMap[widget.actionType]!;

  void _startTraining() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => widget.targetScreen,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final demo = _demo;
    final modelSrc =
        demo.modelSrcs[_currentTab.clamp(0, demo.modelSrcs.length - 1)];
    final hasMultiple = demo.modelSrcs.length > 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // ── 頂欄 ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Color(0xFF374151), size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      '動作示範',
                      style: TextStyle(
                        color: Color(0xFF1A1D2E),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 動作名稱 ──────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.actionName,
                  style: const TextStyle(
                    color: Color(0xFF1A1D2E),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '拖曳可旋轉・雙指縮放・先看示範再開始',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── 3D 模型 ───────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: ModelViewer(
                    key: ValueKey(modelSrc),
                    src: modelSrc,
                    alt: widget.actionName,
                    autoRotate: true,
                    autoRotateDelay: 1000,
                    autoPlay: true,
                    cameraControls: true,
                    backgroundColor: const Color(0xFF1A1D2E),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── 左右切換(只有多模型才顯示)──────────
            if (hasMultiple)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFDDE0F0)),
                  ),
                  child: Row(
                    children: List.generate(demo.tabLabels.length, (i) {
                      final active = _currentTab == i;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _currentTab = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0xFF4A65FF)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              demo.tabLabels[i],
                              style: TextStyle(
                                color: active
                                    ? Colors.white
                                    : const Color(0xFF6B7280),
                                fontSize: 13,
                                fontWeight: active
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            if (hasMultiple) const SizedBox(height: 12),

            // ── 開始訓練按鈕 ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startTraining,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A65FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '開始訓練',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}