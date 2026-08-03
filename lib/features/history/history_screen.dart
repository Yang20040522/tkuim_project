import 'package:flutter/material.dart';
import '../../models/training_action.dart';
import '../../services/history_service.dart';
import 'video_playback_screen.dart';

// ── 分類定義（與 action_list_screen.dart 保持一致）──
//
// 手部復健：翻掌 / 側捏 / 翹手腕 / 左右彎手腕
// 全身復健：抬腳 / 畫圓 / 舉高 / 雙手抬舉 / 手肘前伸 / 坐站 / 側跨步 / 骨架偵測

const List<ActionType> _handActionTypes = [
  ActionType.turnPalm,
  ActionType.sidePinch,
  ActionType.wristExtension,
  ActionType.wristSideBend,
];

const List<ActionType> _bodyActionTypes = [
  ActionType.wipeBody,
  ActionType.drawCircle,
  ActionType.reach,
  ActionType.raiseBothArms,
  ActionType.elbowForward,
  ActionType.sitToStand,
  ActionType.lateralStep,
  ActionType.bodyTest,
];

enum _Category { all, hand, body }

enum _DateFilter { all, today, week, month }

// ── 舊版動作名稱對照 ──
//
// 有些動作在開發過程中改過名字，舊的歷史紀錄裡存的還是改名前的字串，
// 跟現在 kTrainingActions 裡的 name 對不起來。這裡補一個對照表，
// 讓這些舊紀錄還是能正確被歸類，不會因為改名而消失或分類錯誤。
//
// 如果未來又有動作改名，把「舊名稱: ActionType」加進這裡就好。
const Map<String, ActionType> _legacyActionNameAliases = {
  '交扣手肘前伸式': ActionType.elbowForward,   // 手肘屈伸訓練 改名前
  '功能性擦拭訓練': ActionType.wipeBody,        // 站姿抬腳式訓練 改名前
};

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryService _historyService = HistoryService();
  List<TrainingRecord> _allRecords = [];
  bool _isLoading = true;

  _Category _category = _Category.all;
  String _selectedAction = '全部'; // 細項動作名稱，'全部' 代表不篩細項
  _DateFilter _dateFilter = _DateFilter.all;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final records = await _historyService.getHistory();
    setState(() {
      _allRecords = records;
      _isLoading = false;
    });
  }

  Future<void> _clearHistory() async {
    await _historyService.clearHistory();
    setState(() {
      _allRecords = [];
      _category = _Category.all;
      _selectedAction = '全部';
      _dateFilter = _DateFilter.all;
    });
  }

  // ── 動作名稱 <-> ActionType 對照 ──

  ActionType? _typeOfActionName(String name) {
    for (final a in kTrainingActions) {
      if (a.name == name) return a.type;
    }
    return _legacyActionNameAliases[name];
  }

  bool _matchesCategory(TrainingRecord r) {
    if (_category == _Category.all) return true;
    final type = _typeOfActionName(r.actionName);
    if (type == null) return false; // 比對不到就不算進該特定分類
    if (_category == _Category.hand) return _handActionTypes.contains(type);
    return _bodyActionTypes.contains(type);
  }

  // ── 日期篩選 ──

  DateTime? _parseTimestamp(String raw) {
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  bool _matchesDateFilter(TrainingRecord r) {
    if (_dateFilter == _DateFilter.all) return true;
    final dt = _parseTimestamp(r.timestamp);
    if (dt == null) return true; // 無法解析就不過濾掉
    final now = DateTime.now();
    switch (_dateFilter) {
      case _DateFilter.today:
        return dt.year == now.year && dt.month == now.month && dt.day == now.day;
      case _DateFilter.week:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfWeekDay =
            DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return !dt.isBefore(startOfWeekDay);
      case _DateFilter.month:
        return dt.year == now.year && dt.month == now.month;
      case _DateFilter.all:
        return true;
    }
  }

  // 目前大類底下「所有可能的動作」(不論有沒有做過都會列出)
  List<String> get _actionOptionsForCategory {
    final typesForCategory = _category == _Category.all
        ? kTrainingActions.map((a) => a.type).toSet()
        : (_category == _Category.hand ? _handActionTypes : _bodyActionTypes)
            .toSet();

    // 所有動作定義裡屬於這個大類的名稱（含尚未做過的）
    final allPossibleNames = kTrainingActions
        .where((a) => typesForCategory.contains(a.type))
        .map((a) => a.name)
        .toSet();

    // 舊名稱的歷史紀錄也一併納入，確保改名前的紀錄還能被篩選到
    final legacyNamesInCategory = _allRecords.where((r) {
      final type = _typeOfActionName(r.actionName);
      if (type == null) return false;
      return typesForCategory.contains(type);
    }).map((r) => r.actionName);

    final names = <String>{...allPossibleNames, ...legacyNamesInCategory}
        .toList();
    names.sort();
    return ['全部', ...names];
  }

  List<TrainingRecord> get _filteredRecords {
    return _allRecords.where((r) {
      final actionOk =
          _selectedAction == '全部' || r.actionName == _selectedAction;
      return actionOk && _matchesCategory(r) && _matchesDateFilter(r);
    }).toList();
  }

  // 目前選到的細項動作是否從來沒有任何紀錄
  bool get _selectedActionNeverDone {
    if (_selectedAction == '全部') return false;
    return !_allRecords.any((r) => r.actionName == _selectedAction);
  }

  void _setCategory(_Category c) {
    setState(() {
      _category = c;
      _selectedAction = '全部'; // 切換大類時重置細項選擇
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecords;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (!_isLoading && _allRecords.isNotEmpty) ...[
              _buildFilterDropdownRow(),
              const SizedBox(height: 10),
              _buildDateFilterRow(),
              const SizedBox(height: 8),
            ],
            if (!_isLoading && filtered.isNotEmpty) ...[
              _buildChart(filtered),
              const SizedBox(height: 8),
            ],
            _buildListHeader(filtered.length),
            Expanded(
              child: _isLoading ? _buildLoading() : _buildList(filtered),
            ),
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
                  color: Color(0xFF374151), size: 16),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              '訓練進步曲線',
              style: TextStyle(
                color: Color(0xFF1A1D2E),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (_allRecords.isNotEmpty)
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

  // ── 篩選下拉選單（由左到右：大類 → 細項）──

  static const Map<_Category, String> _categoryLabels = {
    _Category.all: '全部類別',
    _Category.hand: '🖐️ 手部復健',
    _Category.body: '🦴 全身復健',
  };

  Widget _buildFilterDropdownRow() {
    final actionOptions = _actionOptionsForCategory;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _buildDropdown<_Category>(
              value: _category,
              items: _Category.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(_categoryLabels[c]!,
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (c) {
                if (c != null) _setCategory(c);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildDropdown<String>(
              value: _selectedAction,
              items: actionOptions
                  .map((name) => DropdownMenuItem(
                        value: name,
                        child: Text(name, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (name) {
                if (name != null) setState(() => _selectedAction = name);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE0F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down,
              color: Color(0xFF6B7280), size: 20),
          borderRadius: BorderRadius.circular(14),
          dropdownColor: const Color(0xFFFFFFFF),
          style: const TextStyle(
            color: Color(0xFF374151),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ── 日期篩選 ──

  Widget _buildDateFilterRow() {
    final items = const [
      _DateFilter.all,
      _DateFilter.today,
      _DateFilter.week,
      _DateFilter.month,
    ];
    final labels = {
      _DateFilter.all: '全部時間',
      _DateFilter.today: '今天',
      _DateFilter.week: '本週',
      _DateFilter.month: '本月',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: items.map((f) {
          final selected = _dateFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _dateFilter = f),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF4A65FF).withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF4A65FF)
                        : const Color(0xFFDDE0F0),
                  ),
                ),
                child: Text(
                  labels[f]!,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF4A65FF)
                        : const Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 圖表 ──

  Widget _buildChart(List<TrainingRecord> records) {
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
              '完美動作次數',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 11),
            ),
            const SizedBox(height: 12),
            Expanded(child: _drawChart(records)),
          ],
        ),
      ),
    );
  }

  Widget _drawChart(List<TrainingRecord> records) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final points = records.asMap().entries.map((e) {
          //final perfect = (10 - e.value.mistakeLogs.length).clamp(0, 10);
          final total = e.value.targetReps;
          final perfect = (total - e.value.mistakeLogs.length).clamp(0, total);
          final x = records.length == 1
              ? w / 2
              : e.key / (records.length - 1) * w;
          //final y = h - (perfect / 10) * h;
          final y = h - (perfect / total) * h;
          return Offset(x, y);
        }).toList();

        return CustomPaint(
          painter: _ChartPainter(points: points, maxH: h),
          child: const SizedBox.expand(),
        );
      },
    );
  }

  Widget _buildListHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          const Text(
            '歷史詳細紀錄',
            style: TextStyle(
              color: Color(0xFF1A1D2E),
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
              '$count',
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

  Widget _buildList(List<TrainingRecord> records) {
    if (_allRecords.isEmpty) {
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
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (records.isEmpty) {
      // 選到的細項動作從來沒有任何紀錄 → 顯示「尚未做過」而不是一般的空篩選提示
      if (_selectedActionNeverDone) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌱', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                '「$_selectedAction」尚未做過',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                '完成一次訓練後這裡就會顯示紀錄',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              ),
            ],
          ),
        );
      }

      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔍', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text(
              '沒有符合篩選條件的紀錄',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              '試試切換分類、動作或時間範圍',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            ),
          ],
        ),
      );
    }

    final reversed = records.reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: reversed.length,
      itemBuilder: (_, i) {
        final record = reversed[i];
        return Dismissible(
          key: ValueKey(record.timestamp),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4B4B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_outline,
                color: Colors.white, size: 22),
          ),
          onDismissed: (_) async {
            await _historyService.removeByTimestamp(record.timestamp);
            if (!mounted) return;
            setState(() {
              _allRecords.removeWhere((r) => r.timestamp == record.timestamp);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('已刪除紀錄'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: _buildRecordCard(record),
        );
      },
    );
  }

  Widget _buildRecordCard(TrainingRecord record) {
    //final perfect = 10 - record.mistakeLogs.length;
    final perfect = (record.targetReps - record.mistakeLogs.length).clamp(0, record.targetReps);
    final minutes = record.durationSeconds ~/ 60;
    final seconds = record.durationSeconds % 60;
    final hasMistakes = record.mistakeLogs.isNotEmpty;
    final hasVideo = record.videoPath != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      color: hasMistakes
                          ? const Color(0xFFFF4B4B)
                          : const Color(0xFF4CAF50),
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
                        color: Color(0xFF1A1D2E),
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
                    //'$perfect / 10',
                    '$perfect / ${record.targetReps}',
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),

          // ── 播放錄影按鈕(只有存在 videoPath 才顯示)───────────────
          if (hasVideo) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VideoPlaybackScreen(
                  videoPath: record.videoPath!,
                  title: '${record.actionName} · ${record.timestamp}',
                ),
              )),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A65FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF4A65FF).withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_outline,
                        color: Color(0xFF4A65FF), size: 18),
                    SizedBox(width: 6),
                    Text(
                      '播放錄影',
                      style: TextStyle(
                        color: Color(0xFF4A65FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

    final gridPaint = Paint()
      ..color = const Color(0xFFDDE0F0)
      ..strokeWidth = 1;
    for (int i = 0; i <= 5; i++) {
      final y = size.height - (i / 5) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

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
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

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

    for (final p in points) {
      canvas.drawCircle(
          p, 6, Paint()..color = const Color(0xFFFF4B4B)..style = PaintingStyle.fill);
      canvas.drawCircle(
          p,
          6,
          Paint()
            ..color = Colors.white.withOpacity(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.points != points;
}