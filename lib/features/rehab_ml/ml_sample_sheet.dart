import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'ml_sample_repository.dart';

/// Local-only review/consent controls. Export is always an explicit action.
class MlSampleSheet extends StatefulWidget {
  const MlSampleSheet({
    super.key,
    required this.repository,
    required this.initialConsent,
    required this.initialSubjectId,
    required this.onConsentChanged,
  });

  final MlSampleRepository repository;
  final bool initialConsent;
  final String? initialSubjectId;
  final void Function(bool consent, String? subjectId) onConsentChanged;

  @override
  State<MlSampleSheet> createState() => _MlSampleSheetState();
}

class _MlSampleSheetState extends State<MlSampleSheet> {
  late final TextEditingController _subjectController;
  late bool _consent;
  List<Map<String, dynamic>> _samples = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _consent = widget.initialConsent;
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
      final samples = await widget.repository.list();
      if (mounted) setState(() => _samples = samples);
    } catch (_) {
      if (mounted) setState(() => _error = '無法讀取研究樣本。');
    }
  }

  void _setConsent(bool enabled) {
    final id = _subjectController.text.trim();
    if (enabled && !RegExp(r'^[A-Za-z0-9_-]{3,40}$').hasMatch(id)) {
      setState(() => _error = '請輸入研究用匿名代碼（3–40 位英數、_ 或 -），不要填姓名或帳號。');
      return;
    }
    setState(() {
      _error = null;
      _consent = enabled;
    });
    widget.onConsentChanged(enabled, enabled ? id : null);
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
              const Text('站姿抬腳研究資料',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                '僅在明確同意後收集 RTMPose 骨架點、信心值與角度；不另存相機影像。現有訓練錄影設定不受此開關控制。資料僅供研究標註，並非醫療診斷。',
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
                title: const Text('同意收集後續完整動作樣本'),
                subtitle: const Text('關閉後立即停止收集；已存樣本可逐筆刪除。'),
                value: _consent,
                onChanged: _setConsent,
              ),
              const Text('模型狀態：等待物理治療師標註及驗證；不顯示 AI 分類。'),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const Divider(height: 32),
              const Text('本機研究樣本',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              if (_samples.isEmpty) const Text('目前沒有可匯出的有效樣本。'),
              for (final sample in _samples)
                ListTile(
                  title: Text(
                      '${sample['movementSide']} · ${sample['capturedAt']}'),
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
