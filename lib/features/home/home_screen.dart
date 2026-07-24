// lib/features/home/home_screen.dart
//
// 首頁(新版)— 儀表板風格 + 底部 5 tab
// 「今日準確度」「連續達成」接 HistoryService 真實資料

import 'package:flutter/material.dart';

import '../../models/training_action.dart';
import '../../services/history_service.dart';
import '../history/history_screen.dart';
import '../training/action_list_screen.dart';
import '../demo/demo_library_screen.dart';   // ← 新增
import '../plan/plan_screen.dart';
import '../demo/standard_analysis_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // ─── 資料層(未來換資料庫只改 HistoryService 內部即可)
  final HistoryService _historyService = HistoryService();

  // ─── 顯示用狀態
  String _accuracyText = '-- %';
  String _accuracyFooter = '尚未開始訓練';
  String _streakText = '0 天';

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _loadStats();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ═══ 載入統計 ═══════════════════════════════════════════════
  // 未來接資料庫時,只動 HistoryService 內部即可,本方法不變
  Future<void> _loadStats() async {
    final records = await _historyService.getHistory();
    if (!mounted) return;

    final acc = _calcTodayAccuracy(records);
    final streak = _calcStreak(records);

    setState(() {
      _accuracyText = acc.text;
      _accuracyFooter = acc.footer;
      _streakText = '$streak 天';
    });
  }

  // 今日準確度:取今天所有 record,(10 - 平均 mistake) / 10 * 100
  ({String text, String footer}) _calcTodayAccuracy(
      List<TrainingRecord> records) {
    final todayPrefix = _todayPrefix();
    final today = records
        .where((r) => r.timestamp.startsWith(todayPrefix))
        .toList();

    if (today.isEmpty) {
      return (text: '-- %', footer: '尚未開始訓練');
    }

    final avgMistakes =
        today.map((r) => r.mistakeLogs.length).reduce((a, b) => a + b) /
            today.length;
    final acc = ((10 - avgMistakes) / 10 * 100).clamp(0, 100).round();

    return (text: '$acc %', footer: '今日完成 ${today.length} 組訓練');
  }

  // 連續達成:從今天往回算,每天至少 1 筆紀錄就 +1
  int _calcStreak(List<TrainingRecord> records) {
    if (records.isEmpty) return 0;

    final days = records.map((r) => r.timestamp.substring(0, 10)).toSet();

    final now = DateTime.now();
    final todayStr = _formatDate(now);
    final yesterdayStr = _formatDate(now.subtract(const Duration(days: 1)));

    // 決定往回算的起始日
    DateTime anchor;
    if (days.contains(todayStr)) {
      anchor = now; // 今天已經練過,從今天開始算
    } else if (days.contains(yesterdayStr)) {
      anchor = now.subtract(const Duration(days: 1)); // 今天還沒練,先用昨天當基準,天數不會歸零
    } else {
      return 0; // 昨天也沒練 → 斷了超過一天,歸零
    }

    int streak = 0;
    DateTime check = anchor;
    while (days.contains(_formatDate(check))) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }
    return streak;
  }

  String _todayPrefix() => _formatDate(DateTime.now());

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ─── 操作:跳「選動作清單」頁,回來後重整統計 ─────────
  void _openActionList() async {
    await Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) => const ActionListScreen(),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 400),
    ));
    if (mounted) _loadStats(); // 訓練回來重算
  }

  // ─── 操作:跳歷史紀錄頁,回來後重整統計(可能清過紀錄)
  void _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
    if (mounted) _loadStats();
  }

  // ← 新增：跳動作示範庫
  void _openDemoLibrary() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DemoLibraryScreen()),
    );
  }

  // ← 新增：跳動作標準分析
  void _openStandardAnalysis() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StandardAnalysisScreen()),
    );
  }

  // ─── 操作:即將開放(鈴鐺、底部 4 tab 共用)
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
          bottom: false,
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
                const SizedBox(height: 12),
                _buildStandardAnalysisCard(),   // ← 新增
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
    return Row(
      children: [
        Expanded(
          child: GestureDetector(           // ✅ 新增
            onTap: _openHistory,            // ✅ 新增:沿用既有的 _openHistory,邏輯完全沒動
            child: _StatCard(
              title: '今日準確度',
              value: _accuracyText,
              footer: _accuracyFooter,
              isPrimary: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: '連續達成 🔥',
            value: _streakText,
            footer: _streakText == '0 天' ? '今天開始吧!' : '保持下去!',
            isPrimary: false,
          ),
        ),
      ],
    );
  }

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

  Widget _buildShortcutsRow() {
    return Row(
      children: [
        Expanded(
          child: _ShortcutCard(
            label: '動作示範庫',
            iconBg: const Color(0xFFD1FAE5),
            onTap: _openDemoLibrary,   // ← 改這裡
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

  Widget _buildStandardAnalysisCard() {
    return GestureDetector(
      onTap: _openStandardAnalysis,
      child: Container(
        width: double.infinity,
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E7FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.insights,
                  color: Color(0xFF4A65FF), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '動作標準分析',
                    style: TextStyle(
                      color: Color(0xFF374151),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '從治療師示範影片建立動作標準',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Color(0xFF9CA3AF), size: 14),
          ],
        ),
      ),
    );
  }

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
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 左右兩組項目,各自平分自己那一半的寬度
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _NavItem(label: '首頁', isActive: true, onTap: () {}),
                        _NavItem(
                            label: '數據',
                            isActive: false,
                            onTap: () => _comingSoon('數據')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 64),   // 保留中間按鈕的空間,避免被擋住
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _NavItem(
                          label: '計畫',
                          isActive: false,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PlanScreen()),
                          ),
                        ),
                        _NavItem(
                            label: '聊天',                 // ✅ 新增
                            isActive: false,
                            onTap: () => _comingSoon('聊天')), // ✅ 先不接畫面
                        _NavItem(
                            label: '個人',
                            isActive: false,
                            onTap: () => _comingSoon('個人')),
                      ],
                    ),
                  ),
                ],
              ),
              // 中間按鈕獨立疊在最上層,永遠釘在 Stack 正中央,不受左右項目數量影響
              _NavCenterButton(onTap: _openActionList),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════ 子元件 ═════════════════════════

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