// lib/widgets/completion_dialog.dart

import 'package:flutter/material.dart';
import '../models/training_action.dart';

// 手部 / 全身動作分類（與 home_screen 相同）
const _handActions = [ActionType.turnPalm, ActionType.sidePinch];
const _bodyActions = [
  ActionType.wipeBody,
  ActionType.drawCircle,
  ActionType.reach,
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
  });

  @override
  Widget build(BuildContext context) {
    final perfectCount = (10 - mistakeLogs.length).clamp(0, 10);
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;

    return Dialog(
      backgroundColor: const Color(0xFF161824),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 10),
              const Text(
                '訓練完成！',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 18),

              // ── 數據列 ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statItem('完美動作', '$perfectCount / 10', const Color(0xFF4A65FF)),
                  _statItem(
                    '花費時間',
                    '$minutes:${seconds.toString().padLeft(2, '0')}',
                    const Color(0xFF4CAF50),
                  ),
                  _statItem(
                    '失誤次數',
                    '${mistakeLogs.length}',
                    mistakeLogs.isEmpty
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF4B4B),
                  ),
                ],
              ),

              const SizedBox(height: 22),
              _divider('接下來要做什麼？'),
              const SizedBox(height: 14),

              // ── 再來一組（相同動作+難度）───────────────────────────
              _actionButton(
                icon: '🔄',
                label: '再來一組',
                subtitle: '${currentAction.name} · ${currentDifficulty.label}',
                color: const Color(0xFF4A65FF),
                onTap: onRetry,
              ),
              const SizedBox(height: 10),

              // ── 切換難度（相同動作的其他難度）──────────────────────
              if (currentAction.difficulties.length > 1) ...[
                _divider('換個難度'),
                const SizedBox(height: 10),
                _DifficultyRow(
                  action: currentAction,
                  currentDifficulty: currentDifficulty,
                  onSelect: (diff) {
                    Navigator.of(context).pop();
                    onStartNew(currentAction, diff);
                  },
                ),
                const SizedBox(height: 10),
              ],

              // ── 選其他動作（改成手部/全身兩個 Accordion）────────────
              _divider('或換個動作'),
              const SizedBox(height: 10),
              _OtherActionsSection(
                currentAction: currentAction,
                onSelect: (action) {
                  Navigator.of(context).pop();
                  onStartNew(action, action.difficulties.first);
                },
              ),

              const SizedBox(height: 14),

              // ── 回首頁 ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: onHome,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF252738)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    '🏠 回到首頁',
                    style: TextStyle(
                        color: Color(0xFFD0D2E0),
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

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Color(0xFF8A8D9F), fontSize: 11)),
      ],
    );
  }

  Widget _divider(String label) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: const Color(0xFF252738))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label,
              style: const TextStyle(
                  color: Color(0xFF555770), fontSize: 11)),
        ),
        Expanded(child: Container(height: 1, color: const Color(0xFF252738))),
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
                        color: Colors.white60, fontSize: 11)),
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
                    ? const Color(0xFF252738)
                    : const Color(0xFF1A2240),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCurrent
                      ? const Color(0xFF555770)
                      : const Color(0xFF4A65FF).withOpacity(0.6),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    diff.label,
                    style: TextStyle(
                      color: isCurrent
                          ? const Color(0xFF555770)
                          : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isCurrent)
                    const Text('目前',
                        style: TextStyle(
                            color: Color(0xFF555770), fontSize: 9)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── 其他動作選擇區（手部 + 全身兩個 Accordion）──────────────────────────────
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
    // 預設展開目前動作所在的分類
    _handExpanded = _handActions.contains(widget.currentAction.type);
    _bodyExpanded = _bodyActions.contains(widget.currentAction.type);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── 手部復健 Accordion ────────────────────────────────────
        _buildAccordion(
          title: '手部復健',
          icon: '🖐️',
          subtitle: '翻掌 · 側捏',
          isExpanded: _handExpanded,
          onToggle: () => setState(() => _handExpanded = !_handExpanded),
          children: kTrainingActions
              .where((a) => _handActions.contains(a.type))
              .map(_buildActionTile)
              .toList(),
        ),
        const SizedBox(height: 8),

        // ── 全身復健 Accordion ────────────────────────────────────
        _buildAccordion(
          title: '全身復健',
          icon: '🦴',
          subtitle: '擦拭 · 畫圓 · 舉高',
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
        color: const Color(0xFF1A1E30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? const Color(0xFF4A65FF).withOpacity(0.5)
              : const Color(0xFF252738),
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
                          ? const Color(0xFF4A65FF).withOpacity(0.15)
                          : const Color(0xFF252738),
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
                                  ? Colors.white
                                  : const Color(0xFFD0D2E0),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            )),
                        Text(subtitle,
                            style: const TextStyle(
                                color: Color(0xFF555770), fontSize: 10)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: Color(0xFF8A8D9F), size: 20),
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
              ? const Color(0xFF252738)
              : const Color(0xFF1A1E30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent
                ? const Color(0xFF555770)
                : const Color(0xFF252738),
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
                            ? const Color(0xFF555770)
                            : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      )),
                  Text(action.description,
                      style: const TextStyle(
                          color: Color(0xFF8A8D9F), fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (isCurrent)
              const Text('目前',
                  style: TextStyle(color: Color(0xFF555770), fontSize: 10))
            else
              const Icon(Icons.arrow_forward_ios,
                  color: Color(0xFF4A65FF), size: 13),
          ],
        ),
      ),
    );
  }
}