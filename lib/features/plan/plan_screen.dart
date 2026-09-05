import 'package:flutter/material.dart';
import 'exercise.dart';
import 'rehab_plan.dart';
import 'plan_repository.dart';
import '../account/app_session.dart';

// ✅ 新增這幾行
import '../../models/training_action.dart';
import '../rehab/training_screen.dart';
import '../rehab/body_training_screen.dart';
import '../../actions/standing_knee_raise_action.dart';
import '../../actions/draw_circle_action.dart';
import '../../actions/reach_action.dart';
import '../../actions/raise_both_arms_action.dart';
import '../../actions/elbow_forward_action.dart';
import '../../actions/sit_to_stand_action.dart';
import '../../actions/lateral_step_action.dart';
import '../../actions/body_rehab_action.dart';

import '../training/training_preview_screen.dart';

class PlanScreen extends StatefulWidget {
  final PlanRepository? repository;

  const PlanScreen({super.key, this.repository});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late final PlanRepository _repository;
  RehabPlan? currentPlan;
  bool isLoading = true;
  String? loadError;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? planRepository;
    _loadPlan(selectedDate);
  }

  Future<void> _loadPlan(DateTime date) async {
    final patientId = AppSession.userId?.trim();
    setState(() {
      isLoading = true;
      loadError = null;
      currentPlan = null;
    });
    if (patientId == null || patientId.isEmpty) {
      setState(() {
        isLoading = false;
        loadError = '找不到登入患者，請重新登入';
      });
      return;
    }

    try {
      final plan = await _repository.getPlanByDate(
        patientId: patientId,
        date: date,
      );
      if (!mounted ||
          AppSession.userId?.trim() != patientId ||
          !_isSameDay(selectedDate, date)) {
        return;
      }
      setState(() {
        currentPlan = plan;
        isLoading = false;
      });
    } on Object catch (error) {
      if (!mounted ||
          AppSession.userId?.trim() != patientId ||
          !_isSameDay(selectedDate, date)) {
        return;
      }
      setState(() {
        isLoading = false;
        loadError = '讀取復健計畫失敗\n$error';
      });
    }
  }

  void _onSelectDay(DateTime date) {
    setState(() => selectedDate = date);
    _loadPlan(date);
  }

  // 病患在所有日期都只能查看；只有今天尚未完成的動作可以開始訓練。
  bool get _isReadOnly {
    final now = DateTime.now();
    final sel =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final today = DateTime(now.year, now.month, now.day);
    return sel.isBefore(today);
  }

  bool get _isToday => _isSameDay(selectedDate, DateTime.now());

  String _planSectionTitle() {
    if (_isToday) return '今日計畫';
    final d = '${selectedDate.month}/${selectedDate.day}';
    return _isReadOnly ? '$d 計畫（唯讀）' : '$d 計畫';
  }

  // 點今日計畫項目 → 導去實際辨識頁面，做完才算完成
  Future<void> _startExercise(
      Exercise exercise, PlanItem item, int realIndex) async {
    final action = kTrainingActions.firstWhere(
      (a) => a.name == exercise.name,
      orElse: () => kTrainingActions.first,
    );
    final difficulty = action.difficulties.first;

    Widget screen;
    if (exercise.category == ExerciseCategory.hand) {
      screen = TrainingScreen(action: action, difficulty: difficulty);
    } else {
      final diff = _mapDifficulty(difficulty.level);
      switch (action.type) {
        case ActionType.wipeBody:
          screen = BodyTrainingScreen(
            action: StandingKneeRaiseAction(
                difficulty: diff, targetCount: difficulty.targetReps),
            trainingActionMeta: action,
            difficultyMeta: difficulty,
          );
        case ActionType.drawCircle:
          screen = BodyTrainingScreen(
            action: DrawCircleAction(
                difficulty: diff, targetCount: difficulty.targetReps),
            trainingActionMeta: action,
            difficultyMeta: difficulty,
          );
        case ActionType.reach:
          screen = BodyTrainingScreen(
            action: ReachAction(
                difficulty: diff, targetCount: difficulty.targetReps),
            trainingActionMeta: action,
            difficultyMeta: difficulty,
          );
        case ActionType.raiseBothArms:
          screen = BodyTrainingScreen(
            action: RaiseBothArmsAction(
                difficulty: diff, targetCount: difficulty.targetReps),
            trainingActionMeta: action,
            difficultyMeta: difficulty,
          );
        case ActionType.elbowForward:
          screen = BodyTrainingScreen(
            action: ElbowForwardAction(
                difficulty: diff, targetCount: difficulty.targetReps),
            trainingActionMeta: action,
            difficultyMeta: difficulty,
          );
        case ActionType.sitToStand:
          screen = BodyTrainingScreen(
            action: SitToStandAction(
                difficulty: diff, targetCount: difficulty.targetReps),
            trainingActionMeta: action,
            difficultyMeta: difficulty,
          );
        case ActionType.lateralStep:
          screen = BodyTrainingScreen(
            action: LateralStepAction(
                difficulty: diff, targetCount: difficulty.targetReps),
            trainingActionMeta: action,
            difficultyMeta: difficulty,
          );
        default:
          screen = TrainingScreen(action: action, difficulty: difficulty);
      }
    }

    // 有 3D 示範的動作 → 先進示範頁;沒有的 → 直接進訓練
    final Widget destination = hasDemo3D(action.type)
        ? TrainingPreviewScreen(
            actionType: action.type,
            actionName: action.name,
            targetScreen: screen,
            difficultyLabel: difficulty.label, // ← 新增
            targetReps: difficulty.targetReps, // ← 新增
            description: action.description, // ← 新增
          )
        : screen;

    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => destination));

    // 回來後重新讀取計畫
    await _loadPlan(selectedDate);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWeekRow(),
                          const SizedBox(height: 24),
                          if (loadError != null)
                            _buildLoadError()
                          else ...[
                            _buildSectionTitle(_planSectionTitle()),
                            const SizedBox(height: 12),
                            _buildTodayPlan(),
                            const SizedBox(height: 24),
                            _buildSectionTitle('本週進度'),
                            const SizedBox(height: 12),
                            _buildWeekProgress(),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        '復健計畫',
        style: TextStyle(
          color: Color(0xFF1A1D2E),
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildLoadError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE0F0)),
      ),
      child: Text(
        loadError!,
        style: const TextStyle(color: Color(0xFFE24B4A), fontSize: 13),
      ),
    );
  }

  Widget _buildWeekRow() {
    final days = ['一', '二', '三', '四', '五', '六', '日'];
    final today = DateTime.now();
    final mondayOfWeek = today.subtract(Duration(days: today.weekday - 1));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE0F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (i) {
          final thisDate = mondayOfWeek.add(Duration(days: i));
          final isSelected = _isSameDay(thisDate, selectedDate);
          final hasPlan = isSelected && currentPlan != null;

          // 過去的日期：日期數字用淡色，讓使用者一眼看出是唯讀
          final dayOnly = DateTime(thisDate.year, thisDate.month, thisDate.day);
          final todayOnly = DateTime(today.year, today.month, today.day);
          final isPast = dayOnly.isBefore(todayOnly);

          return GestureDetector(
            onTap: () => _onSelectDay(thisDate),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  days[i],
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF4A65FF)
                        : const Color(0xFF9CA3AF),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF4A65FF)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${thisDate.day}',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isPast
                                ? const Color(0xFFB5BAC6)
                                : const Color(0xFF374151)),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: hasPlan
                        ? const Color(0xFF4A65FF).withValues(alpha: 0.5)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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

  Widget _buildTodayPlan() {
    if (currentPlan == null || currentPlan!.items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDE0F0)),
        ),
        child: const Text(
          '治療師尚未安排這一天的復健計畫',
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
        ),
      );
    }

    final canTrain = _isToday; // 只有今天能實際開始訓練
    final sortedItems = [...currentPlan!.items]
      ..sort((a, b) => a.order.compareTo(b.order));

    return Column(
      children: sortedItems.map((item) {
        final exercise = findExerciseById(item.exerciseId);
        final realIndex = currentPlan!.items.indexOf(item);
        final onTap = (canTrain && !item.done)
            ? () => _startExercise(exercise, item, realIndex)
            : null;
        return _planItem(exercise, item, onTap: onTap);
      }).toList(),
    );
  }

  Widget _planItem(Exercise exercise, PlanItem item, {VoidCallback? onTap}) {
    final tappable = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.done
                ? const Color(0xFF4A65FF).withValues(alpha: 0.3)
                : const Color(0xFFDDE0F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: item.done
                    ? const Color(0xFF4A65FF)
                    : const Color(0xFFF5F6FA),
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.done
                    ? Icons.check
                    : (tappable ? Icons.play_arrow : Icons.remove),
                color: item.done
                    ? Colors.white
                    : (tappable
                        ? const Color(0xFF4A65FF)
                        : const Color(0xFF9CA3AF)),
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Text(exercise.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: TextStyle(
                      color: item.done
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF1A1D2E),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      decoration: item.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.sets} 組 × ${item.repsPerSet} 下',
                    style:
                        const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                  ),
                ],
              ),
            ),
            // 完成 → 不用額外標示；可訓練(今天,未完成) → 箭頭；
            // 其餘(過去/未來,未完成) → 文字狀態
            if (!item.done && tappable)
              const Icon(Icons.chevron_right,
                  color: Color(0xFF9CA3AF), size: 18)
            else if (!item.done && !tappable)
              Text(
                _isReadOnly ? '未完成' : '尚未開始',
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekProgress() {
    final total = currentPlan?.items.length ?? 0;
    final done = currentPlan?.items.where((i) => i.done).length ?? 0;
    final ratio = total == 0 ? 0.0 : done / total;
    final totalMinutes = currentPlan?.items.fold<int>(0,
            (sum, i) => sum + findExerciseById(i.exerciseId).defaultMinutes) ??
        0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A65FF), Color(0xFF7B5EA7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _progressStat('$done / $total', '完成動作'),
              _progressStat('${(ratio * 100).round()}%', '完成率'),
              _progressStat('$totalMinutes 分鐘', '預估時長'),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            total == 0 ? '這一天尚無計畫' : '完成 ${(ratio * 100).round()}%，繼續加油！',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _progressStat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
      ],
    );
  }
}
