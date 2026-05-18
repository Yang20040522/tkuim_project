// lib/widgets/completion_dialog.dart

import 'package:flutter/material.dart';

class CompletionDialog extends StatelessWidget {
  final int repCount;
  final int durationSeconds;
  final List<String> mistakeLogs;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  const CompletionDialog({
    super.key,
    required this.repCount,
    required this.durationSeconds,
    required this.mistakeLogs,
    required this.onRetry,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final perfectCount = 10 - mistakeLogs.length;
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;

    return Dialog(
      backgroundColor: const Color(0xFF161824),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              '訓練完成！',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statItem('完美動作', '$perfectCount / 10',
                    const Color(0xFF4A65FF)),
                _statItem(
                    '花費時間',
                    '$minutes:${seconds.toString().padLeft(2, '0')}',
                    const Color(0xFF4CAF50)),
                _statItem(
                    '失誤次數',
                    '${mistakeLogs.length}',
                    mistakeLogs.isEmpty
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF4B4B)),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A65FF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  '🔄 再來一組',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
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
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF8A8D9F), fontSize: 11)),
      ],
    );
  }
}
