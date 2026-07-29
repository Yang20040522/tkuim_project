// lib/features/stats/stats_screen.dart
//
// 數據分頁 — 佔位頁面
// 未來會放:訓練趨勢圖、每週統計、錯誤類型分佈等

import 'package:flutter/material.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bar_chart_rounded,
                size: 64,
                color: const Color(0xFF9CA3AF).withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                '數據功能開發中',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '目前不知道要幹嘛',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}