import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../account/app_session.dart';
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
  bool _reviewMode = false;
  bool _canAnnotate = false;
  bool _canReview = false;
  String _reviewRequestStatus = 'NONE';

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
      final access = await _remote.authority();
      final canAnnotate = access['canAnnotate'] == true;
      final canReview = access['canReview'] == true;
      final samples = _reviewMode && canReview
          ? await _remote.reviewQueue()
          : canAnnotate
              ? await _remote.listSamples()
              : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _canAnnotate = canAnnotate;
          _canReview = canReview;
          _reviewRequestStatus =
              access['reviewRequestStatus']?.toString() ?? 'NONE';
          _samples = samples;
        });
      }
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
          (_filter == 'labeled' && status != 'UNLABELED');
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
              if (_canReview)
                SwitchListTile(
                  key: const Key('research-review-mode'),
                  title: const Text('研究審核模式'),
                  subtitle: const Text('僅顯示有權限審核的待審樣本'),
                  value: _reviewMode,
                  onChanged: (value) {
                    setState(() => _reviewMode = value);
                    _load();
                  },
                )
              else if (_reviewRequestStatus == 'PENDING')
                const ListTile(title: Text('研究審核權限申請待核准'))
              else
                TextButton(
                  key: const Key('research-review-request'),
                  onPressed: () async {
                    try {
                      await _remote.requestReviewAccess();
                      await _load();
                    } catch (_) {
                      if (mounted) {
                        setState(() => _error = '申請失敗，請確認患者綁定與研究資格。');
                      }
                    }
                  },
                  child: const Text('申請研究審核權限'),
                ),
              if (!_reviewMode && _canAnnotate)
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
                      '${_statusText(item['annotationStatus']?.toString())}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => ResearchSampleDetailPage(
                          remote: _remote,
                          sampleId: item['id'].toString(),
                          reviewMode: _reviewMode,
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

  String _statusText(String? status) => switch (status) {
        'DRAFT' || 'LABELED' => '草稿',
        'SUBMITTED' => '待審核',
        'APPROVED' => '已核准',
        'RETURNED' => '已退回',
        _ => '待標註',
      };
}

class ResearchSampleDetailPage extends StatefulWidget {
  const ResearchSampleDetailPage(
      {super.key,
      required this.remote,
      required this.sampleId,
      this.reviewMode = false});
  final MlResearchRemote remote;
  final String sampleId;
  final bool reviewMode;

  @override
  State<ResearchSampleDetailPage> createState() =>
      _ResearchSampleDetailPageState();
}

class _ResearchSampleDetailPageState extends State<ResearchSampleDetailPage> {
  Map<String, dynamic>? _detail;
  final TextEditingController _note = TextEditingController();
  final TextEditingController _reviewNote = TextEditingController();
  Timer? _timer;
  int _frame = 0;
  bool _playing = false;
  bool _saving = false;
  String? _label;
  String? _error;
  String? _status;
  String? _annotatorId;

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
          _status = annotation['status']?.toString();
          _annotatorId = annotation['annotatorUserId']?.toString();
        } else {
          _status = null;
          _annotatorId = null;
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

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.remote.submitLabel(widget.sampleId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('標註已提交審核。')));
      }
    } catch (_) {
      if (mounted) setState(() => _error = '提交失敗，請先儲存完整標註。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _review(bool approve) async {
    if (_saving) return;
    if (!approve && _reviewNote.text.trim().isEmpty) {
      setState(() => _error = '退回時請填寫原因。');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.remote
          .reviewLabel(widget.sampleId, approve, _reviewNote.text.trim());
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(approve ? '標註已核准。' : '標註已退回。')));
      }
    } catch (_) {
      if (mounted) setState(() => _error = '審核失敗，請確認權限與樣本狀態。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _note.dispose();
    _reviewNote.dispose();
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
          if (_status != null) Text('標註狀態：$_status'),
          if ((_detail!['annotation'] as Map?)?['reviewNote'] != null)
            Text('審核備註：${(_detail!['annotation'] as Map)['reviewNote']}'),
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
            onChanged: widget.reviewMode ||
                    _status == 'SUBMITTED' ||
                    _status == 'APPROVED'
                ? null
                : (value) => setState(() => _label = value),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _note,
              readOnly: widget.reviewMode ||
                  _status == 'SUBMITTED' ||
                  _status == 'APPROVED',
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: '標註備註', border: OutlineInputBorder())),
          if (!widget.reviewMode &&
              _status != 'SUBMITTED' &&
              _status != 'APPROVED')
            FilledButton(
                onPressed: _saving || _label == null ? null : _save,
                child: const Text('儲存草稿')),
          if (!widget.reviewMode &&
              (_status == 'DRAFT' ||
                  _status == 'RETURNED' ||
                  _status == 'LABELED'))
            OutlinedButton(
              key: const Key('research-submit-label'),
              onPressed: _saving ? null : _submit,
              child: const Text('提交審核'),
            ),
          if (widget.reviewMode &&
              _status == 'SUBMITTED' &&
              _annotatorId != AppSession.userId) ...[
            TextField(
              controller: _reviewNote,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: '審核備註／退回原因'),
            ),
            Row(children: [
              OutlinedButton(
                onPressed: _saving ? null : () => _review(false),
                child: const Text('退回'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saving ? null : () => _review(true),
                child: const Text('核准'),
              ),
            ]),
          ],
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
