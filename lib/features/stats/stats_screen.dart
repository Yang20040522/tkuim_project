// lib/features/stats/stats_screen.dart
//
// 數據分頁 — B+C 混搭空殼:
//   上半 · 弱點分析(雷達圖 + 錯誤分佈)
//   下半 · 激勵回饋(成就徽章 + 個人紀錄 + 週對比)
// 目前全部是佔位,等資料層接上再填。

import 'package:flutter/material.dart';
import 'radar_chart_card.dart';
import 'personal_records_card.dart';
import 'week_summary_card.dart';
import 'badges_card.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              const SizedBox(height: 20),
              const WeekSummaryCard(),
              const SizedBox(height: 28),
              _buildSectionTitle('弱點分析', '看看哪些動作還可以進步'),
              const SizedBox(height: 12),
              const RadarChartCard(),
              const SizedBox(height: 12),
              _buildMistakeTypePlaceholder(),
              const SizedBox(height: 28),
              _buildSectionTitle('成就與紀錄', '你的努力都被記下來了'),
              const SizedBox(height: 12),
              const BadgesCard(),
              const SizedBox(height: 12),
              const PersonalRecordsCard(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 頂部標題 ─────────────────────────────────────────
  Widget _buildTopBar() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '數據',
          style: TextStyle(
            color: Color(0xFF1A1D2E),
            fontSize: 26,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '你的復健表現一目了然',
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
        ),
      ],
    );
  }

  // ─── Section 標題 ─────────────────────────────────────
  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1A1D2E),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
        ),
      ],
    );
  }

  // ─── 錯誤類型分佈佔位 ──────────────────────────────────
  Widget _buildMistakeTypePlaceholder() {
    return _card(
      icon: Icons.pie_chart_outline_rounded,
      iconBg: const Color(0xFFFEE2E2),
      iconColor: const Color(0xFFEF4444),
      title: '錯誤類型分佈',
      body: '你最常犯的錯是什麼?\n(角度不足、姿勢不穩、幅度太小...)',
      height: 140,
    );
  }

  // ─── 通用卡片(給雷達 / 錯誤分佈用)─────────────────────
  Widget _card({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String body,
    required double height,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDE0F0)),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      );
}