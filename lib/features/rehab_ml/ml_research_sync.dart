import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'ml_research_api.dart';
import 'ml_sample_repository.dart';

/// Per-account durable pending IDs. Only newly captured, explicitly consented
/// samples enter this queue; old local-only samples are never silently uploaded.
class MlResearchSync {
  MlResearchSync({required this.remote, required this.local});
  final MlResearchRemote remote;
  final MlSampleRepository local;
  Future<void>? _activeSync;
  bool _stopped = false;
  void stop() => _stopped = true;
  void _check() {
    if (_stopped) throw const MlResearchException('研究同步已停止。');
    local.owner.check();
  }

  String get _key {
    _check();
    final id = local.owner.userId;
    if (id.isEmpty) {
      throw const MlResearchException('請先登入，才能同步研究資料。');
    }
    return 'ml_cloud_pending_$id';
  }

  String get _syncedKey => '${_key}_synced';

  Future<List<String>> pendingIds() async {
    final prefs = await SharedPreferences.getInstance();
    _check();
    return prefs.getStringList(_key) ?? [];
  }

  Future<List<String>> syncedIds() async {
    _check();
    final prefs = await SharedPreferences.getInstance();
    _check();
    return prefs.getStringList(_syncedKey) ?? [];
  }

  Future<void> enqueue(String sampleId) async {
    _check();
    // A persisted, owner-bound sample is required before queuing.
    await local.exportJson(sampleId);
    _check();
    final prefs = await SharedPreferences.getInstance();
    _check();
    final ids = prefs.getStringList(_key) ?? [];
    if (!ids.contains(sampleId)) {
      await prefs.setStringList(_key, [...ids, sampleId]);
    }
  }

  Future<void> discardPending(String sampleId) async {
    _check();
    final prefs = await SharedPreferences.getInstance();
    _check();
    final ids = prefs.getStringList(_key) ?? [];
    ids.remove(sampleId);
    await prefs.setStringList(_key, ids);
  }

  Future<void> withdraw() async {
    _check();
    final consent = await remote.getConsent();
    _check();
    await remote.setConsent(false, consent.currentVersion);
    _check();
    final prefs = await SharedPreferences.getInstance();
    _check();
    await prefs.remove(_key); // Local files remain for explicit review/delete.
  }

  Future<void> deleteCloudData() async {
    _check();
    await remote.deleteMyData();
    _check();
    final prefs = await SharedPreferences.getInstance();
    _check();
    await prefs.remove(_key);
    await prefs.remove(_syncedKey);
  }

  Future<void> sync() => _activeSync ??= _performSync().whenComplete(() {
        _activeSync = null;
      });

  Future<void> _performSync() async {
    final queueKey = _key, syncedKey = _syncedKey;
    final consent = await remote.getConsent();
    _check();
    if (!consent.active || !consent.available) {
      throw const MlResearchException('尚未同意或目前無法同步研究資料。');
    }
    final prefs = await SharedPreferences.getInstance();
    _check();
    for (final id in prefs.getStringList(queueKey) ?? <String>[]) {
      _check();
      final payload = jsonDecode(utf8.decode(await local.exportJson(id)));
      _check();
      if (payload is! Map<String, dynamic>) {
        throw const MlResearchException('本機研究樣本格式錯誤。');
      }
      if (payload['schemaVersion'] == 2 && !consent.handAvailable) continue;
      await remote.upload(payload);
      _check();
      final remaining = prefs.getStringList(queueKey) ?? <String>[];
      remaining.remove(id);
      await prefs.setStringList(queueKey, remaining);
      _check();
      final synced = prefs.getStringList(syncedKey) ?? <String>[];
      if (!synced.contains(id)) {
        await prefs.setStringList(syncedKey, [...synced, id]);
      }
    }
  }
}
