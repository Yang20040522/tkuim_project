import 'package:flutter/material.dart';
import '../account/app_session.dart';
import 'body_research_session.dart';
import 'ml_research_api.dart';

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
      if (mounted && widget.session.owner.isCurrent) {
        setState(() {
          _samples = local.where((s) => s['schemaVersion'] == 3).length;
          _consent = consent;
          _pending = pending.length;
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
