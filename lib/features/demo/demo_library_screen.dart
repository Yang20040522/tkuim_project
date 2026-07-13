// lib/features/demo/demo_library_screen.dart
//
// 動作示範庫 — 顯示 3D .glb 模型

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'bone_viewer_screen.dart';

class DemoLibraryScreen extends StatefulWidget {
  const DemoLibraryScreen({super.key});

  @override
  State<DemoLibraryScreen> createState() => _DemoLibraryScreenState();
}

class _DemoLibraryScreenState extends State<DemoLibraryScreen>
    with TickerProviderStateMixin {
  // ── 手部卡片狀態 ──
  bool _handExpanded = false;
  int _handTab = 0;
  late final AnimationController _handController;
  late final Animation<double> _handExpandAnim;

  // ── 腳部卡片狀態 ──
  bool _legExpanded = false;
  int _legTab = 0;
  late final AnimationController _legController;
  late final Animation<double> _legExpandAnim;

  // ── 畫圓卡片狀態 ──
  bool _circleExpanded = false;
  int _circleTab = 0;
  late final AnimationController _circleController;
  late final Animation<double> _circleExpandAnim;

  @override
  void initState() {
    super.initState();
    _handController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _handExpandAnim = CurvedAnimation(
      parent: _handController,
      curve: Curves.easeInOut,
    );

    _legController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _legExpandAnim = CurvedAnimation(
      parent: _legController,
      curve: Curves.easeInOut,
    );

    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _circleExpandAnim = CurvedAnimation(
      parent: _circleController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _handController.dispose();
    _legController.dispose();
    _circleController.dispose();
    super.dispose();
  }

  void _toggleHand() {
    setState(() => _handExpanded = !_handExpanded);
    _handExpanded ? _handController.forward() : _handController.reverse();
  }

  void _toggleLeg() {
    setState(() => _legExpanded = !_legExpanded);
    _legExpanded ? _legController.forward() : _legController.reverse();
  }

  void _toggleCircle() {
    setState(() => _circleExpanded = !_circleExpanded);
    _circleExpanded ? _circleController.forward() : _circleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDE0F0)),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Color(0xFF374151), size: 16),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            '動作示範庫',
            style: TextStyle(
              color: Color(0xFF1A1D2E),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [

          // ① 手部卡片
          _buildDemoCard(
            emoji: '🙋',
            title: '伸手舉高訓練示範',
            subtitle: '左右手可切換・拖曳旋轉・雙指縮放',
            expanded: _handExpanded,
            onTap: _toggleHand,
            expandAnim: _handExpandAnim,
            tabLabels: const ['左手', '右手'],
            currentTab: _handTab,
            onTabChanged: (i) => setState(() => _handTab = i),
            modelSrc: _handTab == 0
                ? 'assets/models/turn_Right_hand.glb'
                : 'assets/models/turn_Left_hand.glb',
            modelAlt: _handTab == 0 ? '左手舉高示範' : '右手舉高示範',
          ),

          const SizedBox(height: 12),

          // ② 腳部卡片
          _buildDemoCard(
            emoji: '🦵',
            title: '站立抬腿訓練示範',
            subtitle: '左右腳可切換・拖曳旋轉・雙指縮放',
            expanded: _legExpanded,
            onTap: _toggleLeg,
            expandAnim: _legExpandAnim,
            tabLabels: const ['左腳', '右腳'],
            currentTab: _legTab,
            onTabChanged: (i) => setState(() => _legTab = i),
            modelSrc: _legTab == 0
                ? 'assets/models/Standing_Leg_Raise_Right.glb'
                : 'assets/models/Standing_Leg_Raise_left.glb',
            modelAlt: _legTab == 0 ? '左腳抬腿示範' : '右腳抬腿示範',
          ),

          const SizedBox(height: 12),

          // ③ 畫圓卡片（右手示範，左手即將開放）
          _buildDemoCard(
            emoji: '🔄',
            title: '手臂畫圓訓練示範',
            subtitle: '右手示範・拖曳旋轉・雙指縮放',
            expanded: _circleExpanded,
            onTap: _toggleCircle,
            expandAnim: _circleExpandAnim,
            tabLabels: const ['右手'],
            currentTab: _circleTab,
            onTabChanged: (i) => setState(() => _circleTab = i),
            modelSrc: 'assets/models/arm_circle_right.glb',
            modelAlt: '右手畫圓示範',
          ),

          const SizedBox(height: 12),

          // ④ 即時骨架連動入口
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BoneViewerScreen()),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.accessibility_new,
                      color: Color(0xFF00E5FF), size: 20),
                  SizedBox(width: 8),
                  Text(
                    '即時骨架連動（測試）',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }

  // ── 共用卡片 widget ──────────────────────────────────────
  Widget _buildDemoCard({
    required String emoji,
    required String title,
    required String subtitle,
    required bool expanded,
    required VoidCallback onTap,
    required Animation<double> expandAnim,
    required List<String> tabLabels,
    required int currentTab,
    required ValueChanged<int> onTabChanged,
    required String modelSrc,
    required String modelAlt,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDDE0F0)),
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                            color: Color(0xFF1A1D2E),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          )),
                      Text(subtitle,
                          style: const TextStyle(
                              color: Color(0xFF6B7280), fontSize: 12)),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeInOut,
                  child: const Icon(Icons.keyboard_arrow_down,
                      color: Color(0xFF6B7280), size: 22),
                ),
              ],
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: expandAnim,
          axisAlignment: -1,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                if (tabLabels.length > 1)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDDE0F0)),
                    ),
                    child: Row(
                      children: List.generate(tabLabels.length, (i) {
                        final isActive = currentTab == i;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => onTabChanged(i),
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFF4A65FF)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  tabLabels[i],
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : const Color(0xFF6B7280),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                if (tabLabels.length > 1) const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 380,
                    child: ModelViewer(
                      key: ValueKey(modelSrc),
                      src: modelSrc,
                      alt: modelAlt,
                      autoRotate: true,
                      autoRotateDelay: 1000,
                      autoPlay: true,
                      cameraControls: true,
                      backgroundColor: const Color(0xFF1A1D2E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}