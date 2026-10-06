import 'package:flutter/material.dart';
import '../account/app_session.dart';
import 'body_research_session.dart';
import 'ml_research_api.dart';
import 'body_ml_advisory_card.dart';
import 'body_ml_contract.dart';

/// Minimal DPAD-friendly body research settings; not a new research backend.
class BodyResearchSettingsPage extends StatefulWidget {
  const BodyResearchSettingsPage({super.key, required this.session});
  final BodyResearchSession session;
  @override
  State<BodyResearchSettingsPage> createState() =>
      _BodyResearchSettingsPageState();
}

class _BodyResearchSettingsPageState extends State<BodyResearchSettingsPage> {
  MlResearchConsent? _consent;
  String? _error;
  bool _busy = false;
  int _samples = 0, _pending = 0;
  List<Map<String, dynamic>> _resamples = [];
  @override
  void initState() {
    super.initState();
    AppSession.changes.addListener(_accountChanged);
    _load();
  }

  void _accountChanged() {
    if (mounted && !widget.session.owner.isCurrent) {
      setState(() {
        _samples = 0;
        _pending = 0;
        _consent = null;
        _resamples = [];
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
    if (!widget.session.owner.isCurrent) return;
    try {
      final local = await widget.session.repository.list();
      final consent = await widget.session.sync.remote.getConsent();
      final pending = await widget.session.sync.pendingIds();
      final resamples = <Map<String, dynamic>>[];
      if (consent.active) {
        for (var page = 0; page < 25; page++) {
          final rows = await widget.session.sync.remote.listSamples(page: page);
          widget.session.owner.check();
          resamples.addAll(rows.where((s) =>
              s['schemaVersion'] == 3 &&
              s['disposition'] == 'NEEDS_RESAMPLE' &&
              s['exerciseType'] ==
                  widget.session.collector.context.exerciseType &&
              s['exerciseId']?.toString() ==
                  widget.session.collector.context.exerciseId));
          if (rows.length < 20) break;
        }
      }
      if (mounted && widget.session.owner.isCurrent) {
        setState(() {
          _samples = local.where((s) => s['schemaVersion'] == 3).length;
          _consent = consent;
          _pending = pending.length;
          _resamples = resamples;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = MlResearchException.safeMessage(e));
    }
  }

  Future<void> _cloud(bool value) async {
    if (_busy || !widget.session.owner.isCurrent) return;
    if (value &&
        (!widget.session.localConsent || _consent?.available != true)) {
      setState(() => _error = '請先同意本機收集；雲端需有效研究同意及保存政策。');
      return;
    }
    setState(() => _busy = true);
    try {
      final MlResearchConsent consent;
      if (value) {
        consent = await widget.session.sync.remote
            .setConsent(true, _consent?.currentVersion ?? '');
      } else {
        await widget.session.sync.withdraw();
        consent = await widget.session.sync.remote.getConsent();
      }
      widget.session.owner.check();
      widget.session.setCloudConsent(value && consent.active);
      if (mounted) {
        setState(() {
          _consent = consent;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = MlResearchException.safeMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showResample(String id) async {
    try {
      final detail = await widget.session.sync.remote.sampleDetail(id);
      if (!mounted || !widget.session.owner.isCurrent) return;
      final annotation = detail['annotation'] as Map? ?? const {};
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('重採樣審核紀錄'),
                content: SingleChildScrollView(
                    child:
                        Text('原因：${annotation['reasonCode'] ?? 'unavailable'}\n'
                            '備註：${annotation['reviewNote'] ?? ''}\n'
                            '審核者：${annotation['reviewerUserId'] ?? '--'}\n'
                            '審核時間：${annotation['reviewedAt'] ?? '--'}\n'
                            '版本：${annotation['revision'] ?? '--'}')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('返回'))
                ],
              ));
    } catch (_) {
      if (mounted) setState(() => _error = '審核紀錄載入失敗，請重新整理。');
    }
  }

  Future<void> _selectResample(String? id) async {
    if (_busy || !widget.session.owner.isCurrent) return;
    setState(() => _busy = true);
    try {
      await widget.session.selectResample(id);
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted) setState(() => _error = '無法選擇重採樣，請先結束目前動作或重新整理。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Body 研究資料')),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(24), children: [
          const Text('RTMPose 全身研究 · 非醫療診斷',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text(
              '只保存 17 點骨架、未校準 SimCC 分數與 2D 投影特徵，不保存 JPEG。未計次、追蹤中斷的有效嘗試也會記錄。模型尚未部署。'),
          const SizedBox(height: 20),
          ValueListenableBuilder<BodyMlPrediction?>(
              valueListenable: widget.session.advisory.latest,
              builder: (_, prediction, __) =>
                  BodyMlAdvisoryCard(prediction: prediction)),
          CheckboxListTile(
              autofocus: true,
              title: const Text('同意本機 Body attempt 收集'),
              value: widget.session.localConsent,
              onChanged: _busy || !widget.session.owner.isCurrent
                  ? null
                  : (v) async {
                      if (v != true && widget.session.cloudConsent) {
                        await _cloud(false);
                      }
                      if (!mounted || !widget.session.owner.isCurrent) return;
                      widget.session.setLocalConsent(v ?? false);
                      setState(() {});
                    }),
          CheckboxListTile(
              title: const Text('另行同意雲端同步'),
              value: widget.session.cloudConsent,
              onChanged: _busy || !widget.session.owner.isCurrent
                  ? null
                  : (v) => _cloud(v ?? false)),
          Text('本機 $_samples 筆 · 待同步 $_pending 筆'),
          if (widget.session.resampleOfSampleId != null) ...[
            Text('下一個新嘗試將重採樣：${widget.session.resampleOfSampleId}'),
            TextButton(
                onPressed: _busy ? null : () => _selectResample(null),
                child: const Text('取消重採樣選擇')),
          ],
          for (final sample in _resamples)
            Card(
                child: ListTile(
              title: const Text('治療師要求重採樣（不覆寫舊樣本）'),
              onTap: () => _showResample(sample['id'].toString()),
              subtitle: Text(
                  '樣本 ${sample['id']}\n原因：${sample['reasonCode'] ?? '請查看審核備註'}'),
              trailing: TextButton(
                  key: ValueKey('body-select-resample-${sample['id']}'),
                  onPressed: _busy
                      ? null
                      : () => _selectResample(sample['id'].toString()),
                  child: const Text('下次重新收集')),
            )),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ValueListenableBuilder<String?>(
              valueListenable: widget.session.message,
              builder: (_, message, __) => Text(message ?? '研究功能不影響正式復健計次')),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      try {
                        if (widget.session.cloudConsent) {
                          await widget.session.sync.sync();
                        }
                        await _load();
                      } catch (e) {
                        if (mounted) {
                          setState(() =>
                              _error = MlResearchException.safeMessage(e));
                        }
                      }
                    },
              child: const Text('同步／重新整理')),
          OutlinedButton(onPressed: _load, child: const Text('查看本機筆數')),
        ])),
      );
}
