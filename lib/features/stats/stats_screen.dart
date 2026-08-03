// lib/features/stats/stats_screen.dart
//
// 數據分頁 — B+C 混搭空殼:
//   上半 · 弱點分析(雷達圖 + 錯誤分佈)
//   下半 · 激勵回饋(成就徽章 + 個人紀錄 + 週對比)
// 目前全部是佔位,等資料層接上再填。

import 'package:flutter/material.dart';

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
              _buildWeekSummary(),
              const SizedBox(height: 28),
              _buildSectionTitle('弱點分析', '看看哪些動作還可以進步'),
              const SizedBox(height: 12),
              _buildRadarPlaceholder(),
              const SizedBox(height: 12),
              _buildMistakeTypePlaceholder(),
              const SizedBox(height: 28),
              _buildSectionTitle('成就與紀錄', '你的努力都被記下來了'),
              const SizedBox(height: 12),
              _buildBadgesPlaceholder(),
              const SizedBox(height: 12),
              _buildPersonalRecordsPlaceholder(),
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

  // ─── 本週摘要卡(紫色漸層,呼應首頁風格)─────────────────
  Widget _buildWeekSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A65FF), Color(0xFF7B5EA7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本週摘要',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _weekStat('-- 組', '訓練次數')),
              Expanded(child: _weekStat('-- %', '平均準確度')),
              Expanded(child: _weekStat('-- 分', '訓練時長')),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '本週 vs 上週對比,尚未開放',
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 10,
          ),
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

  // ─── 雷達圖佔位 ───────────────────────────────────────
  Widget _buildRadarPlaceholder() {
    return _card(
      icon: Icons.radar_rounded,
      iconBg: const Color(0xFFE0E7FF),
      iconColor: const Color(0xFF4A65FF),
      title: '弱項動作雷達',
      body: '各動作準確度一次呈現,\n一眼看出哪個動作需要加強',
      height: 180,
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

  // ─── 成就徽章佔位 ─────────────────────────────────────
  Widget _buildBadgesPlaceholder() {
    return Container(
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
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '成就徽章',
                      style: TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '0 / 12 已解鎖',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, __) => Container(
                width: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFDDE0F0),
                      style: BorderStyle.solid),
                ),
                child: const Icon(Icons.lock_outline,
                    color: Color(0xFF9CA3AF), size: 22),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '完成訓練解鎖徽章 · 尚未開放',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ─── 個人紀錄佔位 ─────────────────────────────────────
  Widget _buildPersonalRecordsPlaceholder() {
    return Container(
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
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                '個人紀錄',
                style: TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _recordRow('連續達成天數', '-- 天'),
          _recordDivider(),
          _recordRow('單日最多訓練', '-- 組'),
          _recordDivider(),
          _recordRow('累積訓練組數', '-- 組'),
          _recordDivider(),
          _recordRow('最高單組準確度', '-- %'),
        ],
      ),
    );
  }

  Widget _recordRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordDivider() =>
      const Divider(height: 1, color: Color(0xFFF5F6FA));

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