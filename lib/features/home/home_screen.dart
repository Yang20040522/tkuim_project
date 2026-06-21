// lib/features/home/home_screen.dart
//
// 首頁(新版)— 儀表板風格 + 底部 5 tab
// 「開始訓練」大卡片點下去 → ActionListScreen 選動作

import 'package:flutter/material.dart';

import '../history/history_screen.dart';
import '../training/action_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ─── 操作:跳「選動作清單」頁 ─────────────────────────────
  void _openActionList() {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) => const ActionListScreen(),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 400),
    ));
  }

  // ─── 操作:跳歷史紀錄頁 ────────────────────────────────
  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
  }

  // ─── 操作:即將開放(鈴鐺、動作示範庫、底部 4 tab 共用)
  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label 即將開放'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A1D2E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          bottom: false, // 底部 tab bar 自己處理 inset
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopGreeting(),
                const SizedBox(height: 20),
                _buildStatsRow(),
                const SizedBox(height: 28),
                _buildSectionTitle('今日復健計畫'),
                const SizedBox(height: 12),
                _buildMainTrainingCard(),
                const SizedBox(height: 28),
                _buildSectionTitle('功能捷徑'),
                const SizedBox(height: 12),
                _buildShortcutsRow(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // ─── 上方:歡迎詞 + 鈴鐺 ────────────────────────────────
  Widget _buildTopGreeting() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '早安,保持活力 ',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                    ),
                  ),
                  Text('💪', style: TextStyle(fontSize: 14)),
                ],
              ),
              SizedBox(height: 4),
              Text(
                '使用者',
                style: TextStyle(
                  color: Color(0xFF1A1D2E),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '帳號未來綁定',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _comingSoon('通知中心'),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_outlined,
                    color: Color(0xFF374151), size: 22),
                Positioned(
                  top: 10,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
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

  // ─── 數據卡 × 2 ──────────────────────────────────────
  Widget _buildStatsRow() {
    return const Row(
      children: [
        Expanded(
          child: _StatCard(
            title: '今日準確度',
            value: '-- %',
            footer: '尚未開始訓練',
            isPrimary: true,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: '連續達成 🔥',
            value: '0 天',
            footer: '保持下去!',
            isPrimary: false,
          ),
        ),
      ],
    );
  }

  // ─── 區塊標題 ─────────────────────────────────────────
  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF1A1D2E),
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  // ─── 中央「開始訓練」大卡片 ─────────────────────────
  Widget _buildMainTrainingCard() {
    return GestureDetector(
      onTap: _openActionList,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'MediaPipe 核心運算',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '自由訓練',
              style: TextStyle(
                color: Color(0xFF1A1D2E),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '選擇動作 · 多種難度',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D2E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '開始訓練',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 22),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 功能捷徑 × 2 ───────────────────────────────────
  Widget _buildShortcutsRow() {
    return Row(
      children: [
        Expanded(
          child: _ShortcutCard(
            label: '動作示範庫',
            iconBg: const Color(0xFFD1FAE5),
            onTap: () => _comingSoon('動作示範庫'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ShortcutCard(
            label: '歷史紀錄',
            iconBg: const Color(0xFFFFE4D6),
            onTap: _openHistory,
          ),
        ),
      ],
    );
  }

  // ─── 底部 5 tab ─────────────────────────────────────
  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // 首頁(目前在,有底色)
              _NavItem(
                label: '首頁',
                isActive: true,
                onTap: () {}, // 已在首頁
              ),
              // 數據
              _NavItem(
                label: '數據',
                isActive: false,
                onTap: () => _comingSoon('數據'),
              ),
              // 訓練(中間圓鈕)
              _NavCenterButton(
                onTap: _openActionList,
              ),
              // 計畫
              _NavItem(
                label: '計畫',
                isActive: false,
                onTap: () => _comingSoon('計畫'),
              ),
              // 個人
              _NavItem(
                label: '個人',
                isActive: false,
                onTap: () => _comingSoon('個人'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════ 子元件 ═════════════════════════

// 數據卡片(今日準確度 / 連續達成)
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String footer;
  final bool isPrimary;

  const _StatCard({
    required this.title,
    required this.value,
    required this.footer,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isPrimary
        ? const LinearGradient(
            colors: [Color(0xFF4A65FF), Color(0xFF7B5EA7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;
    final textColor =
        isPrimary ? Colors.white : const Color(0xFF1A1D2E);
    final subColor = isPrimary
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: bg,
        color: isPrimary ? null : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: subColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            footer,
            style: TextStyle(color: subColor, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// 功能捷徑方塊
class _ShortcutCard extends StatelessWidget {
  final String label;
  final Color iconBg;
  final VoidCallback onTap;

  const _ShortcutCard({
    required this.label,
    required this.iconBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 底部 nav 項目(左 2 + 右 2 共用)
class _NavItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? const Color(0xFF4A65FF)
        : const Color(0xFF9CA3AF);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight:
                    isActive ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 底部中央訓練圓鈕
class _NavCenterButton extends StatelessWidget {
  final VoidCallback onTap;

  const _NavCenterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A65FF), Color(0xFF6B82FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A65FF).withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(height: 2),
            const Text(
              '訓練',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}