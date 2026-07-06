// lib/features/plan/plan_screen.dart
//
// 復健計畫頁面（範例 UI）
// 目前為示意版本，未來接後端資料

import 'package:flutter/material.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWeekRow(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('今日計畫'),
                    const SizedBox(height: 12),
                    _buildTodayPlan(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('本週進度'),
                    const SizedBox(height: 12),
                    _buildWeekProgress(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('推薦動作'),
                    const SizedBox(height: 12),
                    _buildRecommendList(),
                    const SizedBox(height: 16),
                    _buildComingSoonBanner(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 頂部 bar ──────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDE0F0)),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Color(0xFF374151), size: 16),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '復健計畫',
              style: TextStyle(
                color: Color(0xFF1A1D2E),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          // 未來：新增計畫按鈕
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF4A65FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  // ── 星期列 ─────────────────────────────────────────────
  Widget _buildWeekRow() {
    final days = ['一', '二', '三', '四', '五', '六', '日'];
    final today = DateTime.now().weekday - 1; // 0=週一

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
          final isToday = i == today;
          // 示意：週一、三、五有計畫
          final hasPlan = [0, 2, 4].contains(i);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                days[i],
                style: TextStyle(
                  color: isToday
                      ? const Color(0xFF4A65FF)
                      : const Color(0xFF9CA3AF),
                  fontSize: 12,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: isToday
                      ? const Color(0xFF4A65FF)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${DateTime.now().day - today + i}',
                    style: TextStyle(
                      color: isToday
                          ? Colors.white
                          : const Color(0xFF374151),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // 有計畫的日子顯示小圓點
              Container(
                width: 5, height: 5,
                decoration: BoxDecoration(
                  color: hasPlan
                      ? const Color(0xFF4A65FF).withValues(alpha: 0.5)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── 標題 ────────────────────────────────────────────────
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

  // ── 今日計畫清單（示意資料）──────────────────────────────
  Widget _buildTodayPlan() {
    final plans = [
      (time: '09:00', name: '手腕旋轉', sets: '3 組 × 10 下', done: true),
      (time: '09:15', name: '手肘彎曲伸展', sets: '3 組 × 12 下', done: true),
      (time: '09:30', name: '肩膀上舉', sets: '2 組 × 8 下', done: false),
      (time: '10:00', name: '站立提膝', sets: '3 組 × 10 下', done: false),
    ];

    return Column(
      children: plans.map((p) => _planItem(p)).toList(),
    );
  }

  Widget _planItem(
      ({String time, String name, String sets, bool done}) p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: p.done
              ? const Color(0xFF4A65FF).withValues(alpha: 0.3)
              : const Color(0xFFDDE0F0),
        ),
      ),
      child: Row(
        children: [
          // 完成打勾
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: p.done
                  ? const Color(0xFF4A65FF)
                  : const Color(0xFFF5F6FA),
              shape: BoxShape.circle,
            ),
            child: Icon(
              p.done ? Icons.check : Icons.circle_outlined,
              color: p.done ? Colors.white : const Color(0xFFDDE0F0),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: TextStyle(
                    color: p.done
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF1A1D2E),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    decoration:
                        p.done ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.sets,
                  style: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            p.time,
            style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── 本週進度條 ──────────────────────────────────────────
  Widget _buildWeekProgress() {
    final items = [
      (label: '完成動作', value: '8 / 12'),
      (label: '訓練天數', value: '3 / 5'),
      (label: '總時長', value: '42 分鐘'),
    ];

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
            children: items
                .map((item) => Column(
                      children: [
                        Text(
                          item.value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          // 進度條
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 8 / 12,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '本週完成 67%，繼續加油！',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ── 推薦動作列表（示意）──────────────────────────────────
  Widget _buildRecommendList() {
    final items = [
      (icon: '🙋', name: '伸手舉高', level: '初階', minutes: '10 分鐘'),
      (icon: '🔄', name: '手腕旋轉', level: '初階', minutes: '8 分鐘'),
      (icon: '🦵', name: '站立提膝', level: '中階', minutes: '15 分鐘'),
    ];

    return Column(
      children: items.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDDE0F0)),
          ),
          child: Row(
            children: [
              Text(item.icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: Color(0xFF1A1D2E),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.level} · ${item.minutes}',
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '加入',
                  style: TextStyle(
                    color: Color(0xFF4A65FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── 即將開放 banner ──────────────────────────────────────
  Widget _buildComingSoonBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF4A65FF).withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFF4A65FF), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '計畫功能開發中，目前顯示示意資料。\n未來將支援自訂計畫、治療師指派等功能。',
              style: TextStyle(
                color: Color(0xFF4A65FF),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}