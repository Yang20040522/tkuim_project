// lib/features/demo/demo_library_screen.dart
//
// 動作示範庫 — 顯示 3D .glb 模型
// 「伸手舉高訓練」:1 張卡片,點開有「左手 / 右手」tab 切換

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'bone_viewer_screen.dart'; // 即時骨架連動測試頁面

class DemoLibraryScreen extends StatefulWidget {
  const DemoLibraryScreen({super.key});

  @override
  State<DemoLibraryScreen> createState() => _DemoLibraryScreenState();
}

class _DemoLibraryScreenState extends State<DemoLibraryScreen>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  // 0 = 左手, 1 = 右手
  int _handTab = 0;

  late final AnimationController _controller;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _expandAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _controller.forward() : _controller.reverse();
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
              width: 40,
              height: 40,
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
    // ── 整個 body 是一個 Padding，裡面放一個 Column ──
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        // ── Column 的 children 清單開始 ──
        children: [

          // ① 可點擊的卡片 header（點了展開/收起 3D 模型）
          GestureDetector(
            onTap: _toggle,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDDE0F0)),
              ),
              child: Row(
                children: [
                  const Text('🙋', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '伸手舉高訓練示範',
                          style: TextStyle(
                            color: Color(0xFF1A1D2E),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '左右手可切換・拖曳旋轉・雙指縮放',
                          style: TextStyle(
                              color: Color(0xFF6B7280), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // 箭頭圖示，展開時旋轉 180 度
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeInOut,
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF6B7280),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ① 結束

          // ② 展開區塊：tab 切換 + 3D 模型（高度動畫）
          SizeTransition(
            sizeFactor: _expandAnim,
            axisAlignment: -1,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  // 左手 / 右手 tab
                  _buildHandTab(),
                  const SizedBox(height: 10),
                  // 3D 模型檢視器
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      height: 380,
                      // ValueKey(_handTab) → 切換 tab 時強制重建 ModelViewer
                      child: ModelViewer(
                        key: ValueKey(_handTab),
                        src: _handTab == 0
                            ? 'assets/models/turn_Right_hand.glb'
                            : 'assets/models/turn_Left_hand.glb',
                        alt: _handTab == 0 ? '左手舉高示範' : '右手舉高示範',
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
          // ② 結束

          // ③ 間距
          const SizedBox(height: 12),

          // ④ 即時骨架連動入口按鈕（測試用）
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BoneViewerScreen()),
            ),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          // ④ 結束

        ],
        // ── Column 的 children 清單結束 ──
      ),
    );
  }

  // ─── 左手 / 右手 切換 tab ─────────────────────────────
  Widget _buildHandTab() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE0F0)),
      ),
      child: Row(
        children: [
          _tabButton('左手', 0),
          _tabButton('右手', 1),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int idx) {
    final isActive = _handTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _handTab = idx),
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
              label,
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
  }
}