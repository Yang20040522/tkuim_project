import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'ml_research_api.dart';

typedef ResearchExportSaver = Future<bool> Function(Uint8List bytes);

/// Deliberately small, backend-authorized per-study management surface.
class ResearchManagementPage extends StatefulWidget {
  const ResearchManagementPage({super.key, this.remote, this.saveExport});

  final MlResearchRemote? remote;
  final ResearchExportSaver? saveExport;

  @override
  State<ResearchManagementPage> createState() => _ResearchManagementPageState();
}

class _ResearchManagementPageState extends State<ResearchManagementPage> {
  late final MlResearchRemote _remote = widget.remote ?? MlResearchApi();
  final _userId = TextEditingController();
  final _policyVersion = TextEditingController();
  final _retentionDays = TextEditingController();
  final _effectiveDate = TextEditingController();
  final _approvalReference = TextEditingController();
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _policies = [];
  bool _authorized = false;
  bool _busy = false;
  bool _canAnnotate = false;
  bool _canReview = false;
  bool _canManage = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final authority = await _remote.authority();
      if (authority['canManage'] != true) {
        if (mounted) setState(() => _error = '目前沒有研究管理權限。');
        return;
      }
      final stats = await _remote.managementStats();
      final requests = await _remote.pendingReviewRequests();
      final policies = await _remote.retentionPolicies();
      if (mounted) {
        setState(() {
          _authorized = true;
          _stats = stats;
          _requests = requests;
          _policies = policies;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '研究管理資料載入失敗，請確認授權與連線。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide(int requestId, bool approve) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _remote.decideReviewRequest(requestId, approve);
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = '審核授權處理失敗，請稍後重試。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setGrant() async {
    final targetId = int.tryParse(_userId.text.trim());
    if (_busy || targetId == null || targetId <= 0) {
      setState(() => _error = '請輸入有效的既有帳號 ID。');
      return;
    }
    if (_canManage) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('確認授予研究管理權限'),
          content: Text('將對帳號 $targetId 授予研究管理權限。請先核對對象身分。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('確認授權')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await _remote.setResearchGrant(targetId,
          canAnnotate: _canAnnotate,
          canReview: _canReview,
          canManage: _canManage);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('研究授權已更新。')));
      }
    } catch (_) {
      if (mounted) setState(() => _error = '研究授權更新失敗，請確認帳號與資格。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _remote.exportApproved();
      final saved =
          await (widget.saveExport?.call(bytes) ?? _saveWithPicker(bytes));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(saved ? '已審核資料已儲存，請妥善保管匯出檔。' : '已取消儲存匯出檔。')));
      }
    } catch (_) {
      if (mounted) setState(() => _error = '匯出失敗，請確認權限、資料與儲存位置。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _saveWithPicker(Uint8List bytes) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '儲存已審核研究資料',
      fileName: 'rehab-research-reviewed.zip',
      type: FileType.custom,
      allowedExtensions: ['zip'],
      bytes: bytes,
    );
    return path != null;
  }

  Future<void> _createPolicy() async {
    final version = _policyVersion.text.trim();
    final days = int.tryParse(_retentionDays.text.trim());
    final reference = _approvalReference.text.trim();
    final effective =
        DateTime.tryParse('${_effectiveDate.text.trim()}T00:00:00Z');
    if (_busy ||
        !RegExp(r'^[A-Za-z0-9_.-]{1,64}$').hasMatch(version) ||
        days == null ||
        days < 1 ||
        days > 36500 ||
        effective == null ||
        !RegExp(r'^[A-Za-z0-9_.-]{1,128}$').hasMatch(reference)) {
      setState(() => _error = '請依核准文件填寫版本、保存天數、生效日期與核准編號。');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認研究資料保存政策'),
        content: Text(
            '確認核准文件與保存期限一致：$days 天，自 ${_effectiveDate.text.trim()} 生效。未經核准請勿設定。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('確認建立')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _remote.createRetentionPolicy(
          version: version,
          retentionDays: days,
          effectiveAt: effective,
          approvalReference: reference);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存政策版本已建立。')));
      }
    } catch (_) {
      if (mounted) setState(() => _error = '保存政策建立失敗，請確認版本與授權。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _processExpired() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final count = await _remote.processExpiredSamples();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('本次處理 $count 筆已到期樣本。')));
      }
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = '到期處理失敗，請稍後重試。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _userId.dispose();
    _policyVersion.dispose();
    _retentionDays.dispose();
    _effectiveDate.dispose();
    _approvalReference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(title: const Text('研究管理')),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              const Text('僅限後端授權的研究管理者。研究資料仍受同意、研究範圍與審核狀態限制。'),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              if (_authorized) ...[
                const SizedBox(height: 12),
                Card(
                    child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('研究資料狀態',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('樣本：${_stats?['sampleCount'] ?? 0}'),
                        Text('待審核：${_stats?['pendingReviewCount'] ?? 0}'),
                        Text('已核准：${_stats?['approvedCount'] ?? 0}'),
                      ]),
                )),
                const SizedBox(height: 12),
                Card(
                    child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('研究審核申請',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        if (_requests.isEmpty) const Text('目前沒有待處理申請。'),
                        for (final request in _requests)
                          ListTile(
                            title: Text('帳號 ID：${request['userId']}'),
                            subtitle: const Text('申請研究審核權限'),
                            trailing: Wrap(spacing: 4, children: [
                              TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () =>
                                          _decide(request['id'] as int, false),
                                  child: const Text('拒絕')),
                              TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () =>
                                          _decide(request['id'] as int, true),
                                  child: const Text('核准')),
                            ]),
                          ),
                        const SizedBox(height: 12),
                        Card(
                            child: ExpansionTile(
                          title: const Text('研究資料保存政策'),
                          subtitle: Text(_policies.isEmpty
                              ? '尚未設定正式保存期限；研究收集維持關閉'
                              : '目前有 ${_policies.length} 個政策版本'),
                          childrenPadding: const EdgeInsets.all(16),
                          children: [
                            const Text(
                                '僅在研究計畫與保存期限正式核准後，依核准文件建立版本。建立政策不會自動開啟研究收集。'),
                            for (final policy in _policies)
                              ListTile(
                                  title: Text(
                                      '版本 ${policy['policyVersion']} · ${policy['retentionDays']} 天'),
                                  subtitle: Text(
                                      '生效 ${policy['effectiveAt']} · 到期處理：刪除')),
                            TextField(
                                controller: _policyVersion,
                                decoration:
                                    const InputDecoration(labelText: '核准政策版本')),
                            TextField(
                                controller: _retentionDays,
                                keyboardType: TextInputType.number,
                                decoration:
                                    const InputDecoration(labelText: '核准保存天數')),
                            TextField(
                                controller: _effectiveDate,
                                decoration: const InputDecoration(
                                    labelText: '生效日期（YYYY-MM-DD，UTC）')),
                            TextField(
                                controller: _approvalReference,
                                decoration:
                                    const InputDecoration(labelText: '核准文件編號')),
                            FilledButton(
                                onPressed: _busy ? null : _createPolicy,
                                child: const Text('建立政策版本')),
                            OutlinedButton(
                                onPressed: _busy ? null : _processExpired,
                                child: const Text('處理已到期樣本')),
                          ],
                        )),
                      ]),
                )),
                const SizedBox(height: 12),
                Card(
                    child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('指定／撤銷研究授權',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        TextField(
                            controller: _userId,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: '既有帳號 ID')),
                        CheckboxListTile(
                            title: const Text('標註權限'),
                            value: _canAnnotate,
                            onChanged: (v) =>
                                setState(() => _canAnnotate = v == true)),
                        CheckboxListTile(
                            title: const Text('審核權限'),
                            value: _canReview,
                            onChanged: (v) =>
                                setState(() => _canReview = v == true)),
                        CheckboxListTile(
                            title: const Text('研究管理權限'),
                            value: _canManage,
                            onChanged: (v) =>
                                setState(() => _canManage = v == true)),
                        const Text('儲存會覆寫該帳號在本研究的三項授權；撤銷請取消對應勾選。'),
                        FilledButton(
                            onPressed: _busy ? null : _setGrant,
                            child: const Text('更新授權')),
                      ]),
                )),
                const SizedBox(height: 12),
                Card(
                    child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('已審核資料匯出',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const Text('僅包含有效同意、已獨立核准且可用於訓練的匿名樣本；檔案請儲存在受控位置。'),
                        FilledButton.icon(
                          key: const Key('research-export-approved'),
                          onPressed: _busy ? null : _export,
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('匯出已審核資料'),
                        ),
                      ]),
                )),
              ],
            ]),
          ),
        ),
      );
}
