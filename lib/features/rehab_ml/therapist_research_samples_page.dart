import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../account/app_session.dart';
import 'ml_research_api.dart';
import 'ml_action_definition.dart';
import 'research_sample_presentation.dart';
import 'research_owner_scope.dart';

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
  final Map<String, String> _filters = {};
  int _loadVersion = 0;
  late final ResearchOwnerScope _owner;

  @override
  void initState() {
    super.initState();
    _owner = ResearchOwnerScope.capture();
    AppSession.changes.addListener(_accountChanged);
    _load();
  }

  void _accountChanged() {
    if (mounted && !_owner.isCurrent) {
      ++_loadVersion;
      setState(() {
        _samples = [];
        _canAnnotate = false;
        _canReview = false;
        _loading = false;
        _error = '登入狀態已變更，請重新開啟研究頁面。';
      });
    }
  }

  @override
  void dispose() {
    AppSession.changes.removeListener(_accountChanged);
    super.dispose();
  }

  Future<void> _load() async {
    if (!_owner.isCurrent) return;
    final version = ++_loadVersion;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final access = await _remote.authority();
      final canAnnotate = access['canAnnotate'] == true;
      final canReview = access['canReview'] == true;
      final samples = _reviewMode && canReview
          ? await _remote.reviewQueuePage(0)
          : canAnnotate
              ? await _remote.listSamples()
              : <Map<String, dynamic>>[];
      if (samples.length == 20) {
        for (var page = 1; page < 25; page++) {
          final next = _reviewMode && canReview
              ? await _remote.reviewQueuePage(page)
              : await _remote.listSamples(page: page);
          if (!mounted || version != _loadVersion || !_owner.isCurrent) return;
          samples.addAll(next);
          if (next.length < 20) break;
        }
      }
      if (mounted && version == _loadVersion && _owner.isCurrent) {
        setState(() {
          _canAnnotate = canAnnotate;
          _canReview = canReview;
          _reviewRequestStatus =
              access['reviewRequestStatus']?.toString() ?? 'NONE';
          _samples = samples;
        });
      }
    } catch (_) {
      if (mounted && version == _loadVersion) {
        setState(() => _error = '研究樣本載入失敗，請確認網路與授權。');
      }
    } finally {
      if (mounted && version == _loadVersion) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _samples.where((item) {
      final status = item['annotationStatus'];
      final statusMatches = _filter == 'all' ||
          (_filter == 'pending' && status == 'UNLABELED') ||
          (_filter == 'labeled' && status != 'UNLABELED');
      return statusMatches &&
          ResearchSamplePresentation.matches(item, _filters);
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
              else if (_canAnnotate)
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
                )
              else
                const ListTile(title: Text('尚未取得此研究的標註授權')),
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
              ExpansionTile(
                title: const Text('篩選研究樣本'),
                children: [
                  for (final entry in const {
                    'modality': '資料類型',
                    'source': '來源',
                    'patient': '匿名患者',
                    'exercise': '動作',
                    'session': '訓練 Session',
                    'status': '標註狀態',
                    'disposition': '樣本處置',
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('research-filter-${entry.key}'),
                        initialValue: _filters[entry.key] ?? 'all',
                        isExpanded: true,
                        decoration: InputDecoration(labelText: entry.value),
                        items: [
                          const DropdownMenuItem(
                              value: 'all', child: Text('全部')),
                          for (final value in _filterOptions(entry.key))
                            DropdownMenuItem(
                                value: value,
                                child: Text(value,
                                    overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (value) => setState(() {
                          _filters[entry.key] = value ?? 'all';
                        }),
                      ),
                    ),
                ],
              ),
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
                    title: Text(MlActionRegistry.production
                            .byId(item['actionId']?.toString() ??
                                'standing_knee_raise')
                            ?.displayName ??
                        '尚未支援的研究動作'),
                    subtitle: Text(
                      '樣本 ${item['id']}\n匿名受試者 ${item['subjectId']} · '
                      '${item['movementSide'] == 'left' ? '左側' : '右側'} · '
                      '${item['capturedAt']}\n'
                      '${ResearchSamplePresentation.originLabel(item)} · '
                      '${_statusText(item['annotationStatus']?.toString())} · '
                      '${item['disposition'] ?? 'ACTIVE'}',
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

  List<String> _filterOptions(String key) {
    String value(Map<String, dynamic> item) => switch (key) {
          'modality' => ResearchSamplePresentation.modality(item),
          'source' => ResearchSamplePresentation.source(item),
          'patient' => item['subjectId']?.toString() ?? '',
          'exercise' =>
            (item['exerciseId'] ?? item['actionId'])?.toString() ?? '',
          'session' => item['sessionId']?.toString() ?? '',
          'status' => item['annotationStatus']?.toString() ?? 'UNLABELED',
          _ => item['disposition']?.toString() ?? 'ACTIVE',
        };
    final result =
        _samples.map(value).where((v) => v.isNotEmpty).toSet().toList()..sort();
    final selected = _filters[key];
    if (selected != null && selected != 'all' && !result.contains(selected)) {
      result.add(selected);
    }
    return result;
  }
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

class _ResearchSampleDetailPageState extends State<ResearchSampleDetailPage>
    with WidgetsBindingObserver {
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
  String _reasonCode = 'LOW_QUALITY';
  late final ResearchOwnerScope _owner;
  bool get _bodyAttempt => (_detail?['payload'] as Map?)?['schemaVersion'] == 3;
  int get _revision =>
      ((_detail?['annotation'] as Map?)?['revision'] as num?)?.toInt() ?? 0;
  String get _disposition =>
      (_detail?['sample'] as Map?)?['disposition']?.toString() ?? 'ACTIVE';

  MlActionDefinition? get _definition {
    final payload = _detail?['payload'];
    return payload is Map<String, dynamic>
        ? MlActionRegistry.production.forSample(payload)
        : null;
  }

  Map<String, String> get labels => _definition?.labels ?? const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _owner = ResearchOwnerScope.capture();
    AppSession.changes.addListener(_accountChanged);
    _load();
  }

  void _accountChanged() {
    if (mounted && !_owner.isCurrent) {
      _pause();
      setState(() {
        _detail = null;
        _error = '登入狀態已變更，請重新開啟樣本。';
      });
    }
  }

  Future<void> _load() async {
    if (!_owner.isCurrent) return;
    _timer?.cancel();
    _playing = false;
    try {
      final detail = await widget.remote.sampleDetail(widget.sampleId);
      if (!mounted || !_owner.isCurrent) return;
      setState(() {
        _detail = detail;
        _frame = 0;
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
    _scheduleFrame();
  }

  void _scheduleFrame() {
    if (!_playing || _frame >= _frames.length - 1) {
      _pause();
      return;
    }
    _timer = Timer(ResearchPlaybackTimeline(_frames).intervalAfter(_frame), () {
      if (!mounted || _frame >= _frames.length - 1) {
        _pause();
      } else {
        setState(() => _frame++);
        _scheduleFrame();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  Future<void> _save() async {
    if (_saving || _label == null || _definition == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_bodyAttempt) {
        await widget.remote.labelSampleRevision(
            widget.sampleId, _label!, _note.text.trim(),
            labelVersion: _definition!.labelVersion,
            actionDefinitionVersion: _definition!.version,
            expectedRevision: _revision);
      } else {
        await widget.remote.labelSample(
            widget.sampleId, _label!, _note.text.trim(),
            labelVersion: _definition!.labelVersion,
            actionDefinitionVersion: _definition!.version);
      }
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
    if (_saving || _definition == null) return;
    setState(() => _saving = true);
    try {
      if (_bodyAttempt) {
        await widget.remote.submitLabelRevision(widget.sampleId, _revision);
      } else {
        await widget.remote.submitLabel(widget.sampleId);
      }
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

  Future<void> _review(String decision) async {
    if (_saving) return;
    final approve = decision == 'APPROVE';
    if (!approve && _reviewNote.text.trim().isEmpty) {
      setState(() => _error = '退回時請填寫原因。');
      return;
    }
    setState(() => _saving = true);
    try {
      if (_bodyAttempt) {
        await widget.remote.reviewDecision(
            widget.sampleId, decision, _reviewNote.text.trim(),
            expectedRevision: _revision,
            reasonCode: approve ? null : _reasonCode);
      } else {
        await widget.remote
            .reviewLabel(widget.sampleId, approve, _reviewNote.text.trim());
      }
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
    WidgetsBinding.instance.removeObserver(this);
    AppSession.changes.removeListener(_accountChanged);
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
          Text(_definition?.isHand == true
              ? '21 點手部影像座標；z 為模型估計的相對深度，非真實世界座標；沒有逐點信心值或原始影像。無法可靠判斷時請選「無法評估」。'
              : '僅保存 17 個 2D 骨架點，無原始影像或深度；無法可靠判斷時請選「無法評估」。'),
          const SizedBox(height: 12),
          AspectRatio(
              aspectRatio: 1,
              child: Card(
                  child: CustomPaint(
                key: const Key('research-skeleton-player'),
                painter: ResearchSkeletonPainter(frame?['landmarks'] as List?,
                    isHand: _definition?.isHand == true,
                    bodyPoints: frame?['keypoints'] as List?,
                    validity: frame?['validity'] as List?,
                    imageWidth: (frame?['imageWidth'] as num?)?.toDouble(),
                    imageHeight: (frame?['imageHeight'] as num?)?.toDouble()),
              ))),
          if (frames.isNotEmpty) ...[
            if (ResearchPlaybackTimeline(frames).gapAfter(_frame))
              Text(
                  '追蹤間隔 ${ResearchPlaybackTimeline(frames).intervalAfter(_frame).inMilliseconds} ms（不補點）',
                  key: const Key('research-tracking-gap')),
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
              Text((_definition?.angleLabels.entries ??
                      const <MapEntry<String, String>>[])
                  .where((entry) =>
                      (frame!['angles'] as Map).containsKey(entry.key))
                  .map((entry) =>
                      '${entry.value} ${(frame!['angles'] as Map)[entry.key]}°')
                  .join(' · ')),
          ],
          const SizedBox(height: 16),
          if (_bodyAttempt) _bodySummary(),
          if (_definition == null) const Text('此樣本的動作或資料版本尚未支援，無法標註或提交。'),
          if (_status != null) Text('標註狀態：$_status'),
          if ((_detail!['annotation'] as Map?)?['reviewNote'] != null)
            Text('審核備註：${(_detail!['annotation'] as Map)['reviewNote']}'),
          DropdownButtonFormField<String>(
            key: const Key('research-label'),
            initialValue: labels.containsKey(_label) ? _label : null,
            decoration: const InputDecoration(
                labelText: '動作品質標註', border: OutlineInputBorder()),
            items: labels.entries
                .map((entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ))
                .toList(),
            onChanged: widget.reviewMode ||
                    _disposition != 'ACTIVE' ||
                    _status == 'SUBMITTED' ||
                    _status == 'APPROVED'
                ? null
                : (value) => setState(() => _label = value),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _note,
              readOnly: widget.reviewMode ||
                  _disposition != 'ACTIVE' ||
                  _status == 'SUBMITTED' ||
                  _status == 'APPROVED',
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: '標註備註', border: OutlineInputBorder())),
          if (!widget.reviewMode &&
              _disposition == 'ACTIVE' &&
              _status != 'SUBMITTED' &&
              _status != 'APPROVED')
            FilledButton(
                onPressed: _saving || _label == null || _definition == null
                    ? null
                    : _save,
                child: const Text('儲存草稿')),
          if (!widget.reviewMode &&
              _disposition == 'ACTIVE' &&
              (_status == 'DRAFT' ||
                  _status == 'RETURNED' ||
                  _status == 'LABELED'))
            OutlinedButton(
              key: const Key('research-submit-label'),
              onPressed: _saving || _definition == null ? null : _submit,
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
            if (_bodyAttempt)
              DropdownButtonFormField<String>(
                key: const Key('research-review-reason'),
                initialValue: _reasonCode,
                decoration: const InputDecoration(labelText: '退回／重採樣原因'),
                items: const [
                  DropdownMenuItem(value: 'LOW_QUALITY', child: Text('資料品質不足')),
                  DropdownMenuItem(value: 'TRACKING_LOST', child: Text('追蹤遺失')),
                  DropdownMenuItem(
                      value: 'INCOMPLETE_MOTION', child: Text('動作資料不完整')),
                  DropdownMenuItem(value: 'WRONG_ACTION', child: Text('動作不符')),
                  DropdownMenuItem(value: 'OTHER', child: Text('其他')),
                ],
                onChanged: (value) =>
                    setState(() => _reasonCode = value ?? 'OTHER'),
              ),
            Wrap(spacing: 8, children: [
              OutlinedButton(
                onPressed: _saving ? null : () => _review('RETURN'),
                child: const Text('退回'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saving ? null : () => _review('APPROVE'),
                child: const Text('核准'),
              ),
              if (_bodyAttempt) ...[
                OutlinedButton(
                    key: const Key('research-reject'),
                    onPressed: _saving ? null : () => _review('REJECT'),
                    child: const Text('排除樣本')),
                OutlinedButton(
                    key: const Key('research-needs-resample'),
                    onPressed: _saving ? null : () => _review('NEEDS_RESAMPLE'),
                    child: const Text('需要重採樣')),
              ],
            ]),
          ],
        ],
      ])),
    );
  }

  Widget _bodySummary() {
    final payload = _detail!['payload'] as Map;
    final sample = _detail!['sample'] as Map;
    final names = payload['featureNames'] as List? ?? const [];
    final features = payload['features'] as List? ?? const [];
    const units = {
      'peak_leg_height': '軀幹長比例',
      'minimum_hip_angle_deg': '°（2D）',
      'minimum_knee_angle_deg': '°（2D）',
      'peak_abs_trunk_lean_deg': '°（2D）',
      'duration_seconds': '秒',
    };
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${ResearchSamplePresentation.originLabel(Map<String, dynamic>.from(sample))} · 2D RTMPose'),
                for (final key in [
                  'modality',
                  'source',
                  'schemaVersion',
                  'actionDefinitionVersion',
                  'extractorVersion',
                  'poseModelVersion',
                  'timestampOrigin',
                  'terminationReason',
                  'featuresStatus'
                ])
                  Text('$key：${payload[key] ?? 'unavailable'}'),
                Text('duration：${payload['duration']} 秒'),
                Text(
                    'tracking quality：${(payload['trackingQuality'] as Map?)?['validFrameRatio']}'),
                Text(
                    'set：${payload['setIndex']} · reps：${payload['completedRepsBefore']} → ${payload['completedRepsAfter']}'),
                Text('disposition：$_disposition · revision：$_revision'),
                if (sample['resampleOfSampleId'] != null)
                  Text('重採樣來源：${sample['resampleOfSampleId']}'),
                if (sample['reasonCode'] != null)
                  Text('處置原因：${sample['reasonCode']}'),
                for (var i = 0; i < names.length; i++)
                  Text(
                      '${names[i]}：${i < features.length && features[i] is num ? (features[i] as num).toStringAsFixed(3) : 'unavailable'} ${units[names[i]] ?? ''}',
                      key: ValueKey('research-feature-${names[i]}')),
                const Text('影像平面投影角度，非臨床 3D ROM。'),
              ],
            )));
  }
}

/// COCO 17-point edges; drawing is presentation only, never relabeled/inferred.
class ResearchSkeletonPainter extends CustomPainter {
  const ResearchSkeletonPainter(this.points,
      {this.isHand = false,
      this.bodyPoints,
      this.validity,
      this.imageWidth,
      this.imageHeight});
  final List? points;
  final List? bodyPoints, validity;
  final double? imageWidth, imageHeight;
  final bool isHand;
  static const handEdges = <(int, int)>[
    (0, 1),
    (1, 2),
    (2, 3),
    (3, 4),
    (0, 5),
    (5, 6),
    (6, 7),
    (7, 8),
    (5, 9),
    (9, 10),
    (10, 11),
    (11, 12),
    (9, 13),
    (13, 14),
    (14, 15),
    (15, 16),
    (13, 17),
    (17, 18),
    (18, 19),
    (19, 20),
    (0, 17)
  ];
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
    final values = bodyPoints ?? points;
    if (values == null || values.length != (isHand ? 21 : 17)) return;
    final xy = <Offset?>[];
    for (var index = 0; index < values.length; index++) {
      final raw = values[index];
      if (validity != null &&
          (index >= validity!.length || validity![index] != true)) {
        xy.add(null);
        continue;
      }
      if (raw is! List ||
          raw.length != (isHand ? 3 : 2) ||
          raw[0] is! num ||
          raw[1] is! num) {
        xy.add(null);
        continue;
      }
      final x = (raw[0] as num).toDouble();
      final y = (raw[1] as num).toDouble();
      if (!x.isFinite || !y.isFinite) {
        xy.add(null);
        continue;
      }
      if (bodyPoints != null && (x < 0 || x > 1 || y < 0 || y > 1)) {
        xy.add(null);
        continue;
      }
      xy.add(Offset(x, y));
    }
    final valid = xy.whereType<Offset>().toList();
    if (valid.isEmpty) return;
    final minX = valid.map((p) => p.dx).reduce(math.min);
    final maxX = valid.map((p) => p.dx).reduce(math.max);
    final minY = valid.map((p) => p.dy).reduce(math.min);
    final maxY = valid.map((p) => p.dy).reduce(math.max);
    final span = math.max(math.max(maxX - minX, maxY - minY), 0.01);
    final scale = math.min(size.width, size.height) * 0.8 / span;
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;
    Offset at(int i) {
      if (bodyPoints != null &&
          (imageWidth ?? 0) > 0 &&
          (imageHeight ?? 0) > 0) {
        final s =
            math.min(size.width / imageWidth!, size.height / imageHeight!);
        return Offset(
            (size.width - imageWidth! * s) / 2 + xy[i]!.dx * imageWidth! * s,
            (size.height - imageHeight! * s) / 2 +
                xy[i]!.dy * imageHeight! * s);
      }
      return Offset(size.width / 2 + (xy[i]!.dx - centerX) * scale,
          size.height / 2 + (xy[i]!.dy - centerY) * scale);
    }

    final paint = Paint()
      ..color = const Color(0xFF4A65FF)
      ..strokeWidth = 3;
    for (final (a, b) in isHand ? handEdges : edges) {
      if (xy[a] == null || xy[b] == null) continue;
      canvas.drawLine(at(a), at(b), paint);
    }
    for (var i = 0; i < xy.length; i++) {
      if (xy[i] == null) continue;
      canvas.drawCircle(at(i), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ResearchSkeletonPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.isHand != isHand ||
      oldDelegate.bodyPoints != bodyPoints ||
      oldDelegate.validity != validity ||
      oldDelegate.imageWidth != imageWidth ||
      oldDelegate.imageHeight != imageHeight;
}
