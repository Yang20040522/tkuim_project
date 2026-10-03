import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'ml_sample_repository.dart';
import 'ml_research_api.dart';
import 'ml_research_sync.dart';
import 'ml_quality_evaluator.dart';
import 'ml_action_definition.dart';

/// Explicit research opt-in, local sample review and optional cloud sync.
class MlSampleSheet extends StatefulWidget {
  const MlSampleSheet({
    super.key,
    required this.repository,
    required this.initialConsent,
    required this.initialSubjectId,
    required this.onConsentChanged,
    this.cloudSync,
    this.initialCloudConsent = false,
    this.onCloudConsentChanged,
    this.qualityResult,
    this.definition = MlActionRegistry.standingKneeRaise,
    this.statusMessage,
  });

  final MlSampleRepository repository;
  final bool initialConsent;
  final String? initialSubjectId;
  final void Function(bool consent, String? subjectId) onConsentChanged;
  final MlResearchSync? cloudSync;
  final bool initialCloudConsent;
  final ValueChanged<bool>? onCloudConsentChanged;
  final ValueNotifier<MlQualityResult>? qualityResult;
  final MlActionDefinition definition;
  final ValueNotifier<String?>? statusMessage;

  @override
  State<MlSampleSheet> createState() => _MlSampleSheetState();
}

class _MlSampleSheetState extends State<MlSampleSheet> {
  late final TextEditingController _subjectController;
  late bool _consent;
  List<Map<String, dynamic>> _samples = [];
  String? _error;
  MlResearchConsent? _cloudConsent;
  int _pendingCount = 0;
  int _syncedCount = 0;
  bool _busy = false;
  bool _cloudEnabledForCapture = false;

  @override
  void initState() {
    super.initState();
    _consent = widget.initialConsent;
    _cloudEnabledForCapture = widget.initialCloudConsent;
    _subjectController = TextEditingController(text: widget.initialSubjectId);
    _reload();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final samples = (await widget.repository.list())
          .where((s) => s['actionId'] == widget.definition.actionId)
          .toList();
      if (mounted) setState(() => _samples = samples);
      MlResearchConsent? cloud;
      var pending = 0;
      var synced = 0;
      if (widget.cloudSync != null) {
        cloud = await widget.cloudSync!.remote.getConsent();
        if ((!cloud.active ||
                (widget.definition.isHand && !cloud.handAvailable)) &&
            _cloudEnabledForCapture) {
          _cloudEnabledForCapture = false;
          widget.onCloudConsentChanged?.call(false);
        }
        pending = (await widget.cloudSync!.pendingIds()).length;
        if (cloud.active && cloud.available && pending > 0) {
          await widget.cloudSync!.sync();
          pending = (await widget.cloudSync!.pendingIds()).length;
        }
        synced = (await widget.cloudSync!.syncedIds()).length;
      }
      if (mounted) {
        setState(() {
          _samples = samples;
          _cloudConsent = cloud;
          _pendingCount = pending;
          _syncedCount = synced;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = MlResearchException.safeMessage(error));
      }
    }
  }

  Future<void> _setConsent(bool enabled) async {
    if (_busy) return;
    final id = _subjectController.text.trim();
    if (enabled && !RegExp(r'^[A-Za-z0-9_-]{3,40}$').hasMatch(id)) {
      setState(() => _error = '請輸入研究用匿名代碼（3–40 位英數、_ 或 -），不要填姓名或帳號。');
      return;
    }
    if (!mounted) return;
    setState(() {
      _error = null;
      _consent = enabled;
    });
    widget.onConsentChanged(enabled, enabled ? id : null);
    if (!enabled && _cloudEnabledForCapture) await _setCloudConsent(false);
  }

  Future<void> _setCloudConsent(bool enabled) async {
    if (_busy || widget.cloudSync == null) return;
    if (enabled && !_consent) {
      setState(() => _error = '請先同意本機研究樣本收集。');
      return;
    }
    if (!enabled) {
      _cloudEnabledForCapture = false;
      widget.onCloudConsentChanged?.call(false);
    }
    setState(() => _busy = true);
    try {
      if (enabled) {
        // Refresh before an explicit opt-in; do not reuse a stale closed/version state.
        final state = await widget.cloudSync!.remote.getConsent();
        _cloudConsent = state;
        if (!state.available ||
            (widget.definition.isHand && !state.handAvailable)) {
          throw widget.definition.isHand && !state.handAvailable
              ? const MlResearchException('手部研究範圍與同意版本尚未核准，仍可選擇本機收集。')
              : MlResearchException.unavailable(state.unavailableReason);
        }
        _cloudConsent = await widget.cloudSync!.remote
            .setConsent(true, state.currentVersion);
      } else {
        await widget.cloudSync!.withdraw();
        _cloudConsent = await widget.cloudSync!.remote.getConsent();
      }
      if (mounted) {
        setState(() {
          _cloudEnabledForCapture = enabled;
          _error = null;
        });
      }
      if (mounted) widget.onCloudConsentChanged?.call(enabled);
    } catch (error) {
      if (mounted) {
        setState(() => _error = MlResearchException.safeMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sync() async {
    if (_busy || widget.cloudSync == null) return;
    setState(() => _busy = true);
    try {
      await widget.cloudSync!.sync();
      await _reload();
    } catch (_) {
      if (mounted) setState(() => _error = '雲端同步失敗，樣本仍保留於本機，可稍後重試。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteCloudData() async {
    if (_busy || widget.cloudSync == null) return;
    setState(() {
      _busy = true;
      _consent = false;
      _cloudEnabledForCapture = false;
    });
    widget.onConsentChanged(false, null);
    widget.onCloudConsentChanged?.call(false);
    try {
      await widget.cloudSync!.deleteCloudData();
      await _reload();
    } catch (_) {
      if (mounted) setState(() => _error = '雲端資料刪除失敗，請稍後重試。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(String id) async {
    try {
      final bytes = await widget.repository.exportJson(id);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '匯出匿名骨架樣本',
        fileName: '$id.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(bytes),
      );
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('匿名骨架樣本已匯出。請安全交付標註者。')),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = '匯出失敗，請重試。');
    }
  }

  Future<void> _delete(String id) async {
    try {
      await widget.repository.delete(id);
      if (widget.cloudSync != null) {
        await widget.cloudSync!.discardPending(id);
      }
      await _reload();
    } catch (_) {
      if (mounted) setState(() => _error = '刪除失敗，請重試。');
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('${widget.definition.displayName}研究資料',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                widget.definition.isHand
                    ? '僅在明確同意後收集 MediaPipe 手部 21 點影像座標與動作代理特徵，沒有逐點信心值、真實腕角或握力。第一個完成動作僅用於分段，後續完整週期才保存。雲端另需新研究範圍同意與核准；不另存相機影像。現有錄影設定不受此開關控制。'
                    : '僅在明確同意後收集 RTMPose 骨架點、信心值與角度；雲端同步另需單獨同意。不另存相機影像。現有訓練錄影設定不受此開關控制。資料僅供研究標註，並非醫療診斷。',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subjectController,
                enabled: !_consent,
                decoration: const InputDecoration(
                  labelText: '研究用匿名受試者代碼',
                  helperText: '同一人跨次使用同一代碼；請勿輸入姓名、電話或帳號',
                  border: OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                key: const Key('ml-local-consent'),
                title: const Text('同意收集後續完整動作樣本'),
                subtitle: const Text('僅在本機收集；關閉後停止產生新樣本。'),
                value: _consent,
                onChanged: _busy ? null : _setConsent,
              ),
              if (widget.cloudSync != null) ...[
                SwitchListTile(
                  key: const Key('ml-cloud-consent'),
                  title: const Text('同意雲端同步匿名樣本'),
                  subtitle: const Text('僅上傳啟用後新產生的有效樣本；關閉後停止上傳。'),
                  value: _cloudEnabledForCapture,
                  onChanged: _busy ? null : _setCloudConsent,
                ),
                Text('雲端研究：${_cloudConsent?.active == true ? '已同意' : '未參與'} · '
                    '待同步 $_pendingCount 筆 · 已同步 $_syncedCount 筆'),
                if (_cloudConsent?.subjectId != null)
                  Text('雲端匿名代碼：${_cloudConsent!.subjectId}'),
                TextButton.icon(
                  onPressed:
                      _busy || _cloudConsent?.active != true ? null : _sync,
                  icon: const Icon(Icons.sync),
                  label: const Text('重新同步'),
                ),
                TextButton(
                  onPressed: _busy ? null : _deleteCloudData,
                  child: const Text('刪除我的雲端研究資料'),
                ),
              ],
              if (widget.qualityResult == null)
                const Text('模型狀態：等待物理治療師標註及驗證；不顯示 AI 分類。')
              else
                ValueListenableBuilder<MlQualityResult>(
                  valueListenable: widget.qualityResult!,
                  builder: (_, result, __) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result.available
                          ? '研究模型 ${result.modelVersion}：${widget.definition.labels[result.label]} · 模型機率 ${((result.confidence ?? 0) * 100).toStringAsFixed(1)}%'
                          : '模型狀態：${result.reason}'),
                      if (result.available) Text(result.reason),
                    ],
                  ),
                ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              if (widget.statusMessage != null)
                ValueListenableBuilder<String?>(
                    valueListenable: widget.statusMessage!,
                    builder: (_, value, __) =>
                        value == null ? const SizedBox.shrink() : Text(value)),
              const Divider(height: 32),
              const Text('本機研究樣本',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              if (_samples.isEmpty) const Text('目前沒有可匯出的有效樣本。'),
              for (final sample in _samples)
                ListTile(
                  title: Text(
                      '${sample['movementSide'] == 'unknown' ? '未確認左右側' : sample['movementSide']} · ${sample['capturedAt']}'),
                  subtitle: Text(
                      '匿名代碼 ${sample['subjectId']} · ${(sample['frames'] as List).length} 幀'),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: '匯出',
                        icon: const Icon(Icons.file_download_outlined),
                        onPressed: () => _export(sample['sampleId'] as String),
                      ),
                      IconButton(
                        tooltip: '刪除',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(sample['sampleId'] as String),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
}
