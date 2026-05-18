// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import '../models/training_action.dart';
import 'training_screen.dart';
import 'body_test_screen.dart'; // ✅ 新增
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  TrainingAction? _selectedAction;
  DifficultyOption? _selectedDifficulty;
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

  void _selectAction(TrainingAction action) {
    // ✅ 全身骨架直接跳轉，不需要選難度
    if (action.type == ActionType.bodyTest) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, anim, __) => const BodyTestScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
      return;
    }

    setState(() {
      _selectedAction = action;
      _selectedDifficulty = action.difficulties.first;
    });
  }

  void _startTraining() {
    if (_selectedAction == null || _selectedDifficulty == null) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => TrainingScreen(
          action: _selectedAction!,
          difficulty: _selectedDifficulty!,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildSectionLabel('選擇訓練動作'),
                      const SizedBox(height: 12),
                      // 手部動作卡片（原有的兩個）
                      ...kTrainingActions
                          .where((a) => a.type != ActionType.bodyTest)
                          .map(_buildActionCard),
                      const SizedBox(height: 16),
                      // ✅ 全身骨架測試獨立區塊
                      _buildSectionLabel('實驗功能'),
                      const SizedBox(height: 12),
                      _buildBodyTestCard(),
                      const SizedBox(height: 28),
                      // 難度選擇（只在選了手部動作時顯示）
                      if (_selectedAction != null &&
                          _selectedAction!.type != ActionType.bodyTest) ...[
                        _buildSectionLabel('選擇難度等級'),
                        const SizedBox(height: 12),
                        _buildDifficultySelector(),
                        const SizedBox(height: 32),
                      ],
                      // 開始按鈕（只在選了手部動作時顯示）
                      if (_selectedAction != null &&
                          _selectedAction!.type != ActionType.bodyTest)
                        _buildStartButton(),
                      const SizedBox(height: 16),
                      _buildHistoryButton(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A65FF), Color(0xFF7B5EA7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.self_improvement,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RehabAssist',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'AI 復健訓練助理',
                    style: TextStyle(color: Color(0xFF8A8D9F), fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            '今日復健計畫',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF4A65FF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF8A8D9F),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildActionCard(TrainingAction action) {
    final isSelected = _selectedAction?.type == action.type;
    return GestureDetector(
      onTap: () => _selectAction(action),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1E2B5E).withOpacity(0.9)
              : const Color(0xFF161824),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4A65FF)
                : const Color(0xFF252738),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4A65FF).withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4A65FF).withOpacity(0.2)
                    : const Color(0xFF1E2030),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(action.emoji,
                    style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFFD0D2E0),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    action.description,
                    style: const TextStyle(
                        color: Color(0xFF8A8D9F), fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF4A65FF),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.check, color: Colors.white, size: 14),
              ),
          ],
        ),
      ),
    );
  }

  // ✅ 全身骨架測試專屬卡片（點擊直接跳轉，不需選難度）
  Widget _buildBodyTestCard() {
    return GestureDetector(
      onTap: () => _selectAction(
          kTrainingActions.firstWhere((a) => a.type == ActionType.bodyTest)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF161824),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A3050)),
          gradient: const LinearGradient(
            colors: [Color(0xFF161824), Color(0xFF1A2040)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4).withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF00BCD4).withOpacity(0.3)),
              ),
              child: const Center(
                child: Text('🦴', style: TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '全身骨架偵測',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      // Beta 標籤
                      _BetaBadge(),
                    ],
                  ),
                  SizedBox(height: 3),
                  Text(
                    'RTMPose 全身 133 關鍵點即時追蹤',
                    style: TextStyle(color: Color(0xFF8A8D9F), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Color(0xFF00BCD4), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultySelector() {
    if (_selectedAction == null) return const SizedBox();
    return Row(
      children: _selectedAction!.difficulties.map((diff) {
        final isSelected = _selectedDifficulty?.level == diff.level;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedDifficulty = diff),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4A65FF)
                    : const Color(0xFF161824),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF4A65FF)
                      : const Color(0xFF252738),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    diff.label,
                    style: TextStyle(
                      color:
                          isSelected ? Colors.white : const Color(0xFF8A8D9F),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    diff.description,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white.withOpacity(0.7)
                          : const Color(0xFF555770),
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStartButton() {
    final canStart =
        _selectedAction != null && _selectedDifficulty != null;
    return GestureDetector(
      onTap: canStart ? _startTraining : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: canStart
              ? const LinearGradient(
                  colors: [Color(0xFF4A65FF), Color(0xFF6B82FF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: canStart ? null : const Color(0xFF1E2030),
          borderRadius: BorderRadius.circular(16),
          boxShadow: canStart
              ? [
                  BoxShadow(
                    color: const Color(0xFF4A65FF).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  )
                ]
              : [],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_arrow_rounded,
                color:
                    canStart ? Colors.white : const Color(0xFF555770),
                size: 26,
              ),
              const SizedBox(width: 8),
              Text(
                '開始 AI 訓練',
                style: TextStyle(
                  color: canStart ? Colors.white : const Color(0xFF555770),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryButton() {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const HistoryScreen()),
      ),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF161824),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF252738)),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('📋', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                '查看訓練紀錄',
                style: TextStyle(
                  color: Color(0xFFD0D2E0),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ✅ Beta 標籤元件
class _BetaBadge extends StatelessWidget {
  const _BetaBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF00BCD4).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: const Color(0xFF00BCD4).withOpacity(0.4), width: 1),
      ),
      child: const Text(
        'Beta',
        style: TextStyle(
          color: Color(0xFF00BCD4),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}