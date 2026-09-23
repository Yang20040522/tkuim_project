import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ml_research_api.dart';

class TherapistResearchSamplesPage extends StatefulWidget {
  const TherapistResearchSamplesPage({super.key, this.remote});
  final MlResearchRemote? remote;

  @override
  State<TherapistResearchSamplesPage> createState() =>
      _TherapistResearchSamplesPageState();
}

class _TherapistResearchSamplesPageState
    extends State<TherapistResearchSamplesPage> {
  late final MlResearchRemote _remote = widget.remote ?? MlResearchApi();
  List<Map<String, dynamic>> _samples = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final samples = await _remote.listSamples();
      if (mounted) setState(() => _samples = samples);
    } catch (_) {
      if (mounted) setState(() => _error = '研究樣本載入失敗，請確認網路與授權。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _samples.where((item) {
      final status = item['annotationStatus'];
      return _filter == 'all' ||
          (_filter == 'pending' && status == 'UNLABELED') ||
          (_filter == 'labeled' && status == 'LABELED');
    }).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(title: const Text('研究資料標註')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('僅顯示已同意研究、且與你有效綁定的患者樣本。骨架動畫為 2D 研究資料，不能取代臨床判斷。'),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                ChoiceChip(
                    label: const Text('全部'),
                    selected: _filter == 'all',
                    onSelected: (_) => setState(() => _filter = 'all')),
                ChoiceChip(
                    label: const Text('待標註'),
                    selected: _filter == 'pending',
                    onSelected: (_) => setState(() => _filter = 'pending')),
                ChoiceChip(
                    label: const Text('已標註'),
                    selected: _filter == 'labeled',
                    onSelected: (_) => setState(() => _filter = 'labeled')),
              ]),
              if (_loading) const Center(child: CircularProgressIndicator()),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              if (!_loading && _error == null && visible.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(16), child: Text('目前沒有符合條件的研究樣本。')),
              for (final item in visible)
                Card(
                  child: ListTile(
                    key: ValueKey('research-sample-${item['id']}'),
                    title: const Text('站姿抬腳'),
                    subtitle: Text(
                      '樣本 ${item['id']}\n匿名受試者 ${item['subjectId']} · '
                      '${item['movementSide'] == 'left' ? '左側' : '右側'} · '
                      '${item['capturedAt']}\n'
                      '${item['annotationStatus'] == 'LABELED' ? '已標註' : '待標註'}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => ResearchSampleDetailPage(
                          remote: _remote,
                          sampleId: item['id'].toString(),
                        ),
                      ));
                      if (mounted) _load();
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResearchSampleDetailPage extends StatefulWidget {
  const ResearchSampleDetailPage(
      {super.key, required this.remote, required this.sampleId});
  final MlResearchRemote remote;
  final String sampleId;

  @override
  State<ResearchSampleDetailPage> createState() =>
      _ResearchSampleDetailPageState();
}

class _ResearchSampleDetailPageState extends State<ResearchSampleDetailPage> {
  Map<String, dynamic>? _detail;
  final TextEditingController _note = TextEditingController();
  Timer? _timer;
  int _frame = 0;
  bool _playing = false;
  bool _saving = false;
  String? _label;
  String? _error;

  static const labels = <String, String>{
    'meets_requirement': '符合指定動作要求',
    'insufficient_range': '活動幅度不足',
    'trunk_compensation': '軀幹代償',
    'unassessable': '無法評估',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await widget.remote.sampleDetail(widget.sampleId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        final annotation = detail['annotation'];
        if (annotation is Map) {
          _label = annotation['label']?.toString();
          _note.text = annotation['note']?.toString() ?? '';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = '樣本無法載入，請確認權限或稍後重試。');
    }
  }

  List<dynamic> get _frames =>
      ((_detail?['payload'] as Map?)?['frames'] as List?) ?? const [];

  void _pause() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _playing = false);
  }

  void _play() {
    if (_frames.isEmpty) return;
    if (_frame >= _frames.length - 1) setState(() => _frame = 0);
    _timer?.cancel();
    setState(() => _playing = true);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _frame >= _frames.length - 1) {
        _pause();
      } else {
        setState(() => _frame++);
      }
    });
  }

  Future<void> _save() async {
    if (_saving || _label == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.remote
          .labelSample(widget.sampleId, _label!, _note.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('研究標註已儲存。')));
      }
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = '標註儲存失敗，請稍後重試。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frames = _frames;
    final frame = frames.isEmpty ? null : frames[_frame] as Map;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(title: const Text('研究樣本與標註')),
      body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
        if (_detail == null && _error == null)
          const Center(child: CircularProgressIndicator()),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        if (_detail != null) ...[
          Text(
              '樣本 ${widget.sampleId} · 匿名受試者 ${(_detail!['sample'] as Map)['subjectId']}'),
          const SizedBox(height: 8),
          const Text('僅保存 17 個 2D 骨架點，無原始影像或深度；無法可靠判斷時請選「無法評估」。'),
          const SizedBox(height: 12),
          AspectRatio(
              aspectRatio: 1,
              child: Card(
                  child: CustomPaint(
                key: const Key('research-skeleton-player'),
                painter: ResearchSkeletonPainter(frame?['landmarks'] as List?),
              ))),
          if (frames.isNotEmpty) ...[
            Text(
                '第 ${_frame + 1} / ${frames.length} 幀 · ${frame?['timestampMs']} ms'),
            Slider(
              value: _frame.toDouble(),
              max: math.max(1, frames.length - 1).toDouble(),
              onChanged: (value) {
                _pause();
                setState(() => _frame = value.round());
              },
            ),
            Row(children: [
              IconButton(
                  onPressed: _playing ? _pause : _play,
                  icon: Icon(_playing ? Icons.pause : Icons.play_arrow)),
              TextButton(
                  onPressed: () {
                    _pause();
                    setState(() => _frame = 0);
                  },
                  child: const Text('重新播放')),
            ]),
            if (frame?['angles'] is Map)
              Text('髖角 ${(frame!['angles'] as Map)['hipDeg']}° · '
                  '膝角 ${(frame['angles'] as Map)['kneeDeg']}° · '
                  '軀幹傾斜 ${(frame['angles'] as Map)['trunkLeanDeg']}°'),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('research-label'),
            initialValue: _label,
            decoration: const InputDecoration(
                labelText: '動作品質標註', border: OutlineInputBorder()),
            items: labels.entries
                .map((entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _label = value),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _note,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: '標註備註', border: OutlineInputBorder())),
          FilledButton(
              onPressed: _saving || _label == null ? null : _save,
              child: const Text('儲存標註')),
        ],
      ])),
    );
  }
}

/// COCO 17-point edges; drawing is presentation only, never relabeled/inferred.
class ResearchSkeletonPainter extends CustomPainter {
  const ResearchSkeletonPainter(this.points);
  final List? points;
  static const edges = <(int, int)>[
    (5, 6),
    (5, 7),
    (7, 9),
    (6, 8),
    (8, 10),
    (5, 11),
    (6, 12),
    (11, 12),
    (11, 13),
    (13, 15),
    (12, 14),
    (14, 16),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final values = points;
    if (values == null || values.length != 17) return;
    final xy = <Offset>[];
    for (final raw in values) {
      if (raw is! List || raw.length != 2 || raw[0] is! num || raw[1] is! num) {
        return;
      }
      final x = (raw[0] as num).toDouble();
      final y = (raw[1] as num).toDouble();
      if (!x.isFinite || !y.isFinite) return;
      xy.add(Offset(x, y));
    }
    final minX = xy.map((p) => p.dx).reduce(math.min);
    final maxX = xy.map((p) => p.dx).reduce(math.max);
    final minY = xy.map((p) => p.dy).reduce(math.min);
    final maxY = xy.map((p) => p.dy).reduce(math.max);
    final span = math.max(math.max(maxX - minX, maxY - minY), 0.01);
    final scale = math.min(size.width, size.height) * 0.8 / span;
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;
    Offset at(int i) => Offset(size.width / 2 + (xy[i].dx - centerX) * scale,
        size.height / 2 + (xy[i].dy - centerY) * scale);
    final paint = Paint()
      ..color = const Color(0xFF4A65FF)
      ..strokeWidth = 3;
    for (final (a, b) in edges) {
      canvas.drawLine(at(a), at(b), paint);
    }
    for (var i = 0; i < xy.length; i++) {
      canvas.drawCircle(at(i), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ResearchSkeletonPainter oldDelegate) =>
      oldDelegate.points != points;
}
