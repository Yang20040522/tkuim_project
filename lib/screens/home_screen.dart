// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import '../models/training_action.dart';
import 'training_screen.dart';
import 'body_test_screen.dart';
import 'history_screen.dart';
import 'body_training_screen.dart';
import '../actions/wipe_body_action.dart';
import '../actions/draw_circle_action.dart';
import '../actions/reach_action.dart';
import '../actions/raise_both_arms_action.dart';
import '../actions/elbow_forward_action.dart';
import '../actions/sit_to_stand_action.dart';
import '../actions/lateral_step_action.dart';

import '../actions/body_rehab_action.dart';

// 手部動作清單
final _handActions = [
  ActionType.turnPalm,
  ActionType.sidePinch,
  ActionType.wristExtension,  // 第11 翹手腕式
  ActionType.wristSideBend,   // 第10 左右彎手腕式
];
// 全身動作清單
final _bodyActions = [
  ActionType.wipeBody,
  ActionType.drawCircle,
  ActionType.reach,
  ActionType.raiseBothArms,   // 第3 雙手抬舉式
  ActionType.elbowForward,    // 第8 交扣手肘前伸式
  ActionType.sitToStand,    // ← 加這行
  ActionType.lateralStep,
  ActionType.bodyTest,
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  TrainingAction? _selectedAction;
  DifficultyOption? _selectedDifficulty;

  // 控制兩個選單的展開狀態
  bool _handExpanded = false;
  bool _bodyExpanded = false;

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
    if (action.type == ActionType.bodyTest) {
      Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (_, anim, __) => const BodyTestScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ));
      return;
    }
    setState(() {
      _selectedAction = action;
      _selectedDifficulty = action.difficulties.first;
    });
  }

  void _startTraining({TrainingAction? action, DifficultyOption? difficulty}) {
    final act = action ?? _selectedAction;
    final diff = difficulty ?? _selectedDifficulty;
    if (act == null || diff == null) return;

    Widget screen;
    if (act.type == ActionType.wipeBody) {
      screen = BodyTrainingScreen(
        action: WipeBodyAction(difficulty: _mapDifficulty(diff.level)),
        trainingActionMeta: act,
        difficultyMeta: diff,
      );
    } else if (act.type == ActionType.drawCircle) {
      screen = BodyTrainingScreen(
        action: DrawCircleAction(difficulty: _mapDifficulty(diff.level)),
        trainingActionMeta: act,
        difficultyMeta: diff,
      );
    } else if (act.type == ActionType.reach) {
      screen = BodyTrainingScreen(
        action: ReachAction(difficulty: _mapDifficulty(diff.level)),
        trainingActionMeta: act,
        difficultyMeta: diff,
      );
    } else if (act.type == ActionType.raiseBothArms) {
      screen = BodyTrainingScreen(
        action: RaiseBothArmsAction(difficulty: _mapDifficulty(diff.level)),
        trainingActionMeta: act,
        difficultyMeta: diff,
      );
    } else if (act.type == ActionType.elbowForward) {
      screen = BodyTrainingScreen(
        action: ElbowForwardAction(difficulty: _mapDifficulty(diff.level)),
        trainingActionMeta: act,
        difficultyMeta: diff,
      );
    } else if (act.type == ActionType.sitToStand) {       // ← 新增從這裡
      screen = BodyTrainingScreen(
        action: SitToStandAction(difficulty: _mapDifficulty(diff.level)),
        trainingActionMeta: act,
        difficultyMeta: diff,
      );
    } else if (act.type == ActionType.lateralStep) {
      screen = BodyTrainingScreen(
        action: LateralStepAction(difficulty: _mapDifficulty(diff.level)),
        trainingActionMeta: act,
        difficultyMeta: diff,
      );
    } else {
      screen = TrainingScreen(action: act, difficulty: diff);
    }

    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) => screen,
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 400),
    ));
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
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // ── 手部復健選單 ────────────────────────────────
                      _buildAccordion(
                        title: '手部復健',
                        icon: '🖐️',
                        subtitle: '翻掌 · 側捏 · 翹手腕 · 左右彎手腕',
                        isExpanded: _handExpanded,
                        onToggle: () => setState(() {
                          _handExpanded = !_handExpanded;
                          // 展開手部時，如果有選全身動作則清除
                          if (_handExpanded && _selectedAction != null &&
                              _bodyActions.contains(_selectedAction!.type)) {
                            _selectedAction = null;
                            _selectedDifficulty = null;
                          }
                        }),
                        child: Column(
                          children: kTrainingActions
                              .where((a) => _handActions.contains(a.type))
                              .map(_buildActionCard)
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // ── 全身復健選單 ────────────────────────────────
                      _buildAccordion(
                        title: '全身復健',
                        icon: '🦴',
                        subtitle: '擦拭 · 畫圓 · 舉高 · 雙手抬舉 · 手肘前伸 · 坐站 · 骨架偵測',
                        isExpanded: _bodyExpanded,
                        onToggle: () => setState(() {
                          _bodyExpanded = !_bodyExpanded;
                          if (_bodyExpanded && _selectedAction != null &&
                              _handActions.contains(_selectedAction!.type)) {
                            _selectedAction = null;
                            _selectedDifficulty = null;
                          }
                        }),
                        child: Column(
                          children: [
                            // 一般全身動作
                            ...kTrainingActions
                                .where((a) =>
                                    _bodyActions.contains(a.type) &&
                                    a.type != ActionType.bodyTest)
                                .map(_buildActionCard),
                            // bodyTest 特殊卡片
                            _buildBodyTestCard(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── 難度選擇 + 開始按鈕 ─────────────────────────
                      if (_selectedAction != null &&
                          _selectedAction!.type != ActionType.bodyTest) ...[
                        _buildSectionLabel('選擇難度等級'),
                        const SizedBox(height: 10),
                        _buildDifficultySelector(),
                        const SizedBox(height: 20),
                        _buildStartButton(),
                        const SizedBox(height: 12),
                      ],

                      // ── 歷史紀錄按鈕 ────────────────────────────────
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

  // ── 可展開選單 ──────────────────────────────────────────────────────────────
  Widget _buildAccordion({
    required String title,
    required String icon,
    required String subtitle,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: const Color(0xFF161824),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExpanded
              ? const Color(0xFF4A65FF).withOpacity(0.5)
              : const Color(0xFF252738),
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // 標頭列
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isExpanded
                          ? const Color(0xFF4A65FF).withOpacity(0.15)
                          : const Color(0xFF1E2030),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(icon,
                          style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: isExpanded
                                ? Colors.white
                                : const Color(0xFFD0D2E0),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                              color: Color(0xFF555770), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: Color(0xFF8A8D9F), size: 22),
                  ),
                ],
              ),
            ),
          ),

          // 展開內容
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: child,
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
          ),
        ],
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
          const SizedBox(height: 24),
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
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1E2B5E).withOpacity(0.9)
              : const Color(0xFF1A1E30),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4A65FF)
                : const Color(0xFF252738),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4A65FF).withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4A65FF).withOpacity(0.2)
                    : const Color(0xFF252738),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(action.emoji,
                    style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.name,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFFD0D2E0),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action.description,
                    style: const TextStyle(
                        color: Color(0xFF8A8D9F), fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Color(0xFF4A65FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 13),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyTestCard() {
    return GestureDetector(
      onTap: () => _selectAction(
          kTrainingActions.firstWhere((a) => a.type == ActionType.bodyTest)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF00BCD4).withOpacity(0.3)),
              ),
              child: const Center(
                child: Text('🦴', style: TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      _BetaBadge(),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    'RTMPose 全身 133 關鍵點即時追蹤',
                    style: TextStyle(color: Color(0xFF8A8D9F), fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Color(0xFF00BCD4), size: 14),
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
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF8A8D9F),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
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
    final canStart = _selectedAction != null && _selectedDifficulty != null;
    return GestureDetector(
      onTap: canStart ? _startTraining : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 58,
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
                color: canStart ? Colors.white : const Color(0xFF555770),
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
        height: 54,
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

  RehabDifficulty _mapDifficulty(DifficultyLevel level) {
    switch (level) {
      case DifficultyLevel.level1:
        return RehabDifficulty.easy;
      case DifficultyLevel.level2:
        return RehabDifficulty.medium;
      case DifficultyLevel.level3:
        return RehabDifficulty.hard;
    }
  }
}

class _BetaBadge extends StatelessWidget {
  const _BetaBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF00BCD4).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border:
            Border.all(color: const Color(0xFF00BCD4).withOpacity(0.4), width: 1),
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