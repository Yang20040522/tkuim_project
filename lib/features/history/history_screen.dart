import 'package:flutter/material.dart';
import '../../models/training_action.dart';
import '../../services/history_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryService _historyService = HistoryService();
  List<TrainingRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final records = await _historyService.getHistory();
    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  Future<void> _clearHistory() async {
    await _historyService.clearHistory();
    setState(() => _records = []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (!_isLoading && _records.isNotEmpty) ...[
              _buildChart(),
              const SizedBox(height: 8),
            ],
            _buildListHeader(),
            Expanded(child: _isLoading ? _buildLoading() : _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDE0F0)),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: const Color(0xFF374151), size: 16),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              '訓練進步曲線',
              style: TextStyle(
                color: const Color(0xFF1A1D2E),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (_records.isNotEmpty)
            GestureDetector(
              onTap: () => _showClearDialog(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDDE0F0)),
                ),
                child: const Text(
                  '清除',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDDE0F0)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '完美動作次數 (滿分 10)',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 11),
            ),
            const SizedBox(height: 12),
            Expanded(child: _drawChart()),
          ],
        ),
      ),
    );
  }

  Widget _drawChart() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final points = _records.asMap().entries.map((e) {
          final perfect = (10 - e.value.mistakeLogs.length).clamp(0, 10);
          final x = _records.length == 1
              ? w / 2
              : e.key / (_records.length - 1) * w;
          final y = h - (perfect / 10) * h;
          return Offset(x, y);
        }).toList();

        return CustomPaint(
          painter: _ChartPainter(points: points, maxH: h),
          child: const SizedBox.expand(),
        );
      },
    );
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          const Text(
            '歷史詳細紀錄',
            style: TextStyle(
              color: const Color(0xFF1A1D2E),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF4A65FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_records.length}',
              style: const TextStyle(
                color: Color(0xFF4A65FF),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
          color: Color(0xFF4A65FF), strokeWidth: 2),
    );
  }

  Widget _buildList() {
    if (_records.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📋', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text(
              '尚無訓練紀錄',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              '完成第一次訓練後會顯示在這裡',
              style:
                  TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            ),
          ],
        ),
      );
    }

    final reversed = _records.reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: reversed.length,
      itemBuilder: (_, i) => _buildRecordCard(reversed[i], i),
    );
  }

  Widget _buildRecordCard(TrainingRecord record, int index) {
    final perfect = 10 - record.mistakeLogs.length;
    final minutes = record.durationSeconds ~/ 60;
    final seconds = record.durationSeconds % 60;
    final hasMistakes = record.mistakeLogs.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE0F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hasMistakes
                  ? const Color(0xFFFF4B4B).withOpacity(0.15)
                  : const Color(0xFF4CAF50).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$perfect',
                style: TextStyle(
                  color:
                      hasMistakes ? const Color(0xFFFF4B4B) : const Color(0xFF4CAF50),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.actionName,
                  style: const TextStyle(
                    color: const Color(0xFF1A1D2E),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${record.timestamp}  •  Lv.${record.difficulty}  •  '
                  '$minutes:${seconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hasMistakes ? '❌ ${record.mistakeLogs.length} 次失誤' : '✅ 完美',
                style: TextStyle(
                  color: hasMistakes
                      ? const Color(0xFFFF4B4B)
                      : const Color(0xFF4CAF50),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$perfect / 10',
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFF5F6FA),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('清除所有紀錄',
            style: TextStyle(color: Color(0xFF1A1D2E))),
        content: const Text('這個操作無法復原，確定要清除嗎？',
            style: TextStyle(color: Color(0xFF6B7280))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearHistory();
            },
            child: const Text('清除',
                style: TextStyle(color: Color(0xFFFF4B4B))),
          ),
        ],
      ),
    );
  }
}

// ── 折線圖畫筆 ──

class _ChartPainter extends CustomPainter {
  final List<Offset> points;
  final double maxH;

  _ChartPainter({required this.points, required this.maxH});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // 背景格線
    final gridPaint = Paint()
      ..color = const Color(0xFFDDE0F0)
      ..strokeWidth = 1;
    for (int i = 0; i <= 5; i++) {
      final y = size.height - (i / 5) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 填充區域
    if (points.length > 1) {
      final fillPath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        final cp1 = Offset(
            (points[i - 1].dx + points[i].dx) / 2, points[i - 1].dy);
        final cp2 = Offset(
            (points[i - 1].dx + points[i].dx) / 2, points[i].dy);
        fillPath.cubicTo(
            cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i].dx, points[i].dy);
      }
      fillPath
        ..lineTo(points.last.dx, size.height)
        ..lineTo(points.first.dx, size.height)
        ..close();
      canvas.drawPath(
          fillPath,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF4A65FF).withOpacity(0.4),
                const Color(0xFF4A65FF).withOpacity(0.0),
              ],
            ).createShader(
                Rect.fromLTWH(0, 0, size.width, size.height)));

      // 折線
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        final cp1 = Offset(
            (points[i - 1].dx + points[i].dx) / 2, points[i - 1].dy);
        final cp2 = Offset(
            (points[i - 1].dx + points[i].dx) / 2, points[i].dy);
        linePath.cubicTo(
            cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i].dx, points[i].dy);
      }
      canvas.drawPath(
          linePath,
          Paint()
            ..color = const Color(0xFF4A65FF)
            ..strokeWidth = 3
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round);
    }

    // 資料點
    for (final p in points) {
      canvas.drawCircle(p, 6,
          Paint()..color = const Color(0xFFFF4B4B)..style = PaintingStyle.fill);
      canvas.drawCircle(p, 6,
          Paint()
            ..color = Colors.white.withOpacity(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.points != points;
}