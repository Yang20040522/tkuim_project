// lib/features/demo/demo_library_screen.dart

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'bone_viewer_screen.dart';

// ── 動作分類 ──────────────────────────────────────────────
enum DemoCategory { all, arm, fullBody }

// ── 動作資料模型 ──────────────────────────────────────────
class _DemoItem {
  final String emoji;
  final String title;
  final String subtitle;
  final List<String> tabLabels;
  final List<String> modelSrcs;
  final List<String> modelAlts;
  final DemoCategory category;

  const _DemoItem({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.tabLabels,
    required this.modelSrcs,
    required this.modelAlts,
    required this.category,
  });
}

class DemoLibraryScreen extends StatefulWidget {
  const DemoLibraryScreen({super.key});

  @override
  State<DemoLibraryScreen> createState() => _DemoLibraryScreenState();
}

class _DemoLibraryScreenState extends State<DemoLibraryScreen>
    with TickerProviderStateMixin {

  DemoCategory _selectedCategory = DemoCategory.all;

  // ── 所有動作資料 ──────────────────────────────────────────
  final List<_DemoItem> _items = const [
    _DemoItem(
      emoji: '🙋',
      title: '伸手舉高訓練',
      subtitle: '左右手可切換・拖曳旋轉・雙指縮放',
      tabLabels: ['左手', '右手'],
      modelSrcs: [
        'assets/models/turn_Right_hand.glb',
        'assets/models/turn_Left_hand.glb',
      ],
      modelAlts: ['左手舉高示範', '右手舉高示範'],
      category: DemoCategory.arm,
    ),
    _DemoItem(
      emoji: '🔄',
      title: '手臂畫圓訓練',
      subtitle: '右手示範・拖曳旋轉・雙指縮放',
      tabLabels: ['右手'],
      modelSrcs: ['assets/models/arm_circle_right.glb'],
      modelAlts: ['右手畫圓示範'],
      category: DemoCategory.arm,
    ),
    _DemoItem(
      emoji: '🙌',
      title: '雙手抬舉訓練',
      subtitle: '拖曳旋轉・雙指縮放',
      tabLabels: ['示範'],
      modelSrcs: ['assets/models/Both_Arms_Arise.glb'],
      modelAlts: ['雙手抬舉示範'],
      category: DemoCategory.fullBody,
    ),
    _DemoItem(
      emoji: '🦵',
      title: '站立抬腿訓練',
      subtitle: '左右腳可切換・拖曳旋轉・雙指縮放',
      tabLabels: ['左腳', '右腳'],
      modelSrcs: [
        'assets/models/Standing_Leg_Raise_Right.glb',
        'assets/models/Standing_Leg_Raise_left.glb',
      ],
      modelAlts: ['左腳抬腿示範', '右腳抬腿示範'],
      category: DemoCategory.fullBody,
    ),
    // ← 加在這裡
    _DemoItem(
      emoji: '💪',
      title: '手肘屈伸訓練',
      subtitle: '拖曳旋轉・雙指縮放',
      tabLabels: ['示範'],
      modelSrcs: ['assets/models/elbow_flexion_extension.glb'],
      modelAlts: ['手肘屈伸示範'],
      category: DemoCategory.arm,
    ),
  ];

  // ── 每張卡片的展開狀態 & tab index ──────────────────────
  late final List<bool> _expanded;
  late final List<int> _tabIndex;
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _expanded = List.filled(_items.length, false);
    _tabIndex = List.filled(_items.length, 0);
    _controllers = List.generate(
      _items.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 320),
      ),
    );
    _anims = _controllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeInOut))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggle(int idx) {
    setState(() => _expanded[idx] = !_expanded[idx]);
    _expanded[idx] ? _controllers[idx].forward() : _controllers[idx].reverse();
  }

  List<_DemoItem> get _filteredItems => _selectedCategory == DemoCategory.all
      ? _items
      : _items.where((item) => item.category == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            _buildCategoryTabs(),
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

  // ── 分類 tab ───────────────────────────────────────────
  Widget _buildCategoryTabs() {
    final tabs = [
      (category: DemoCategory.all, label: '全部', icon: Icons.grid_view_rounded),
      (category: DemoCategory.arm, label: '手部', icon: Icons.back_hand_outlined),
      (category: DemoCategory.fullBody, label: '全身', icon: Icons.accessibility_new),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: tabs.map((tab) {
          final isActive = _selectedCategory == tab.category;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = tab.category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF4A65FF)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF4A65FF)
                        : const Color(0xFFDDE0F0),
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFF4A65FF).withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab.icon,
                      size: 18,
                      color: isActive ? Colors.white : const Color(0xFF6B7280),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tab.label,
                      style: TextStyle(
                        color: isActive ? Colors.white : const Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    final filtered = _filteredItems;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          // 動作卡片列表
          ...filtered.map((item) {
            final idx = _items.indexOf(item);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildDemoCard(
                item: item,
                idx: idx,
              ),
            );
          }),

          // 即時骨架連動入口
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BoneViewerScreen()),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1D2E), Color(0xFF2D3250)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A1D2E).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.accessibility_new,
                      color: Color(0xFF00E5FF), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '即時骨架連動',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E5FF),
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                    child: const Text(
                      'BETA',
                      style: TextStyle(
                        color: Color(0xFF1A1D2E),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
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

  Widget _buildDemoCard({
    required _DemoItem item,
    required int idx,
  }) {
    final expanded = _expanded[idx];
    final currentTab = _tabIndex[idx];
    final modelSrc = item.modelSrcs[currentTab.clamp(0, item.modelSrcs.length - 1)];
    final modelAlt = item.modelAlts[currentTab.clamp(0, item.modelAlts.length - 1)];

    return Column(
      children: [
        // header
        GestureDetector(
          onTap: () => _toggle(idx),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDDE0F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(item.emoji,
                        style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: const TextStyle(
                            color: Color(0xFF1A1D2E),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 2),
                      Text(item.subtitle,
                          style: const TextStyle(
                              color: Color(0xFF6B7280), fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: expanded
                        ? const Color(0xFF4A65FF)
                        : const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeInOut,
                    child: Icon(Icons.keyboard_arrow_down,
                        color: expanded ? Colors.white : const Color(0xFF6B7280),
                        size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 展開區塊
        SizeTransition(
          sizeFactor: _anims[idx],
          axisAlignment: -1,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                if (item.tabLabels.length > 1)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDDE0F0)),
                    ),
                    child: Row(
                      children: List.generate(item.tabLabels.length, (i) {
                        final isActive = currentTab == i;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _tabIndex[idx] = i),
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFF4A65FF)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  item.tabLabels[i],
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
                if (item.tabLabels.length > 1) const SizedBox(height: 10),
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