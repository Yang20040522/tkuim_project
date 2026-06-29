// lib/widgets/completion_dialog.dart

import 'package:flutter/material.dart';
import '../models/training_action.dart';

// 手部動作清單(與 home_screen 同步)
const _handActions = [
  ActionType.turnPalm,
  ActionType.sidePinch,
  ActionType.wristExtension,
  ActionType.wristSideBend,
];

// 全身動作清單(與 home_screen 同步)
const _bodyActions = [
  ActionType.wipeBody,
  ActionType.drawCircle,
  ActionType.reach,
  ActionType.raiseBothArms,
  ActionType.elbowForward,
  ActionType.bodyTest,
];

class CompletionDialog extends StatelessWidget {
  final int repCount;
  final int durationSeconds;
  final List<String> mistakeLogs;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  final TrainingAction currentAction;
  final DifficultyOption currentDifficulty;
  final void Function(TrainingAction action, DifficultyOption difficulty) onStartNew;

  /// 暫停模式:標題改「訓練暫停」、文案改成「剛剛做了 X 下,辛苦了」
  final bool isPaused;

  const CompletionDialog({
    super.key,
    required this.repCount,
    required this.durationSeconds,
    required this.mistakeLogs,
    required this.onRetry,
    required this.onHome,
    required this.currentAction,
    required this.currentDifficulty,
    required this.onStartNew,
    this.isPaused = false,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    final timeText = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isPaused ? '⏸️' : '🎉', style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 10),
              Text(
                isPaused ? '訓練暫停' : '訓練完成',
                style: const TextStyle(
                    color: Color(0xFF1A1D2E),
                    fontSize: 24,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 18),

              // ── 資訊區:有溫度的文案 + 時長/難度 ───────────────────
              _buildInfoBlock(timeText),

              const SizedBox(height: 22),
              _divider(isPaused ? '想做什麼?' : '接下來要做什麼?'),
              const SizedBox(height: 14),

              // ── 再來一組(相同動作+難度)───────────────────────────
              _actionButton(
                icon: '🔄',
                label: isPaused ? '繼續訓練' : '再來一組',
                subtitle: '${currentAction.name} · ${currentDifficulty.label}',
                color: const Color(0xFF4A65FF),
                onTap: onRetry,
              ),
              const SizedBox(height: 10),

              // ── 切換難度(相同動作的其他難度)──────────────────────
              if (currentAction.difficulties.length > 1) ...[
                _divider('換個難度'),
                const SizedBox(height: 10),
                _DifficultyRow(
                  action: currentAction,
                  currentDifficulty: currentDifficulty,
                  onSelect: (diff) => onStartNew(currentAction, diff),
                ),
                const SizedBox(height: 10),
              ],

              // ── 選其他動作(手部/全身兩個 Accordion)────────────────
              _divider('或換個動作'),
              const SizedBox(height: 10),
              _OtherActionsSection(
                currentAction: currentAction,
                onSelect: (action) => onStartNew(action, action.difficulties.first),
              ),

              const SizedBox(height: 14),

              // ── 回首頁 ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: onHome,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFDDE0F0)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    '🏠 回到首頁',
                    style: TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 資訊區:有溫度的文案 + 時長 + 難度 ───────────────────
  Widget _buildInfoBlock(String timeText) {
    final mainText = isPaused
        ? '你剛剛做了 $repCount 下,辛苦了'
        : '恭喜完成 $repCount 下,做得很棒!';
    final difficultyPrefix = isPaused ? '目前難度' : '通關難度';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE0F0)),
      ),
      child: Column(
        children: [
          Text(
            mainText,
            style: const TextStyle(
              color: Color(0xFF1A1D2E),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined,
                  color: Color(0xFF6B7280), size: 14),
              const SizedBox(width: 4),
              Text(
                '時長 $timeText',
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 12),
              ),
              const SizedBox(width: 16),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFFB0B3C5),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '$difficultyPrefix ${currentDifficulty.label}',
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider(String label) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: const Color(0xFFDDE0F0))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label,
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 11)),
        ),
        Expanded(child: Container(height: 1, color: const Color(0xFFDDE0F0))),
      ],
    );
  }

  Widget _actionButton({
    required String icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 難度切換列 ─────────────────────────────────────────────────────────────
class _DifficultyRow extends StatelessWidget {
  final TrainingAction action;
  final DifficultyOption currentDifficulty;
  final void Function(DifficultyOption) onSelect;

  const _DifficultyRow({
    required this.action,
    required this.currentDifficulty,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: action.difficulties.map((diff) {
        final isCurrent = diff.level == currentDifficulty.level;
        return Expanded(
          child: GestureDetector(
            onTap: isCurrent ? null : () => onSelect(diff),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: BoxDecoration(
                color: isCurrent
                    ? const Color(0xFFEDEFF7)
                    : const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCurrent
                      ? const Color(0xFFDDE0F0)
                      : const Color(0xFF4A65FF).withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    diff.label,
                    style: TextStyle(
                      color: isCurrent
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF1A1D2E),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isCurrent)
                    const Text('目前',
                        style: TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 9)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── 其他動作選擇區(手部 + 全身兩個 Accordion)──────────────────────────────
class _OtherActionsSection extends StatefulWidget {
  final TrainingAction currentAction;
  final void Function(TrainingAction) onSelect;

  const _OtherActionsSection({
    required this.currentAction,
    required this.onSelect,
  });

  @override
  State<_OtherActionsSection> createState() => _OtherActionsSectionState();
}

class _OtherActionsSectionState extends State<_OtherActionsSection> {
  late bool _handExpanded;
  late bool _bodyExpanded;

  @override
  void initState() {
    super.initState();
    _handExpanded = _handActions.contains(widget.currentAction.type);
    _bodyExpanded = _bodyActions.contains(widget.currentAction.type);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildAccordion(
          title: '手部復健',
          icon: '🖐️',
          subtitle: '翻掌 · 側捏 · 翹手腕 · 左右彎手腕',
          isExpanded: _handExpanded,
          onToggle: () => setState(() => _handExpanded = !_handExpanded),
          children: kTrainingActions
              .where((a) => _handActions.contains(a.type))
              .map(_buildActionTile)
              .toList(),
        ),
        const SizedBox(height: 8),
        _buildAccordion(
          title: '全身復健',
          icon: '🦴',
          subtitle: '擦拭 · 畫圓 · 舉高 · 雙手抬舉 · 手肘前伸',
          isExpanded: _bodyExpanded,
          onToggle: () => setState(() => _bodyExpanded = !_bodyExpanded),
          children: kTrainingActions
              .where((a) =>
                  _bodyActions.contains(a.type) &&
                  a.type != ActionType.bodyTest)
              .map(_buildActionTile)
              .toList(),
        ),
      ],
    );
  }

  Widget _buildAccordion({
    required String title,
    required String icon,
    required String subtitle,
    required bool isExpanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? const Color(0xFF4A65FF).withValues(alpha: 0.5)
              : const Color(0xFFDDE0F0),
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isExpanded
                          ? const Color(0xFF4A65FF).withValues(alpha: 0.15)
                          : const Color(0xFFEDEFF7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                        child: Text(icon, style: const TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                              color: isExpanded
                                  ? const Color(0xFF1A1D2E)
                                  : const Color(0xFF374151),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            )),
                        Text(subtitle,
                            style: const TextStyle(
                                color: Color(0xFF9CA3AF), fontSize: 10)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: Color(0xFF6B7280), size: 20),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(children: children),
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

  Widget _buildActionTile(TrainingAction action) {
    final isCurrent = action.type == widget.currentAction.type;
    return GestureDetector(
      onTap: isCurrent ? null : () => widget.onSelect(action),
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrent
              ? const Color(0xFFEDEFF7)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent
                ? const Color(0xFFDDE0F0)
                : const Color(0xFFDDE0F0),
          ),
        ),
        child: Row(
          children: [
            Text(action.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(action.name,
                      style: TextStyle(
                        color: isCurrent
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF1A1D2E),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      )),
                  Text(action.description,
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (isCurrent)
              const Text('目前',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10))
            else
              const Icon(Icons.arrow_forward_ios,
                  color: Color(0xFF4A65FF), size: 13),
          ],
        ),
      ),
    );
  }
}