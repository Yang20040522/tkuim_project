import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../account/app_session.dart';
import 'ml_research_api.dart';
import 'ml_sample_repository.dart';

/// Per-account durable pending IDs. Only newly captured, explicitly consented
/// samples enter this queue; old local-only samples are never silently uploaded.
class MlResearchSync {
  MlResearchSync({required this.remote, required this.local});
  final MlResearchRemote remote;
  final MlSampleRepository local;
  Future<void>? _activeSync;

  String get _key {
    final id = AppSession.userId?.trim();
    if (id == null || id.isEmpty) {
      throw const MlResearchException('請先登入，才能同步研究資料。');
    }
    return 'ml_cloud_pending_$id';
  }

  String get _syncedKey => '${_key}_synced';

  Future<List<String>> pendingIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  Future<List<String>> syncedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_syncedKey) ?? [];
  }

  Future<void> enqueue(String sampleId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? [];
    if (!ids.contains(sampleId)) {
      await prefs.setStringList(_key, [...ids, sampleId]);
    }
  }

  Future<void> discardPending(String sampleId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_key) ?? [];
    ids.remove(sampleId);
    await prefs.setStringList(_key, ids);
  }

  Future<void> withdraw() async {
    final consent = await remote.getConsent();
    await remote.setConsent(false, consent.currentVersion);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key); // Local files remain for explicit review/delete.
  }

  Future<void> deleteCloudData() async {
    await remote.deleteMyData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_syncedKey);
  }

  Future<void> sync() => _activeSync ??= _performSync().whenComplete(() {
        _activeSync = null;
      });

  Future<void> _performSync() async {
    final owner = AppSession.userId;
    final consent = await remote.getConsent();
    if (!consent.active || !consent.available) {
      throw const MlResearchException('尚未同意或目前無法同步研究資料。');
    }
    final prefs = await SharedPreferences.getInstance();
    final queueKey = _key;
    for (final id in prefs.getStringList(queueKey) ?? <String>[]) {
      if (AppSession.userId != owner) return;
      final payload = jsonDecode(utf8.decode(await local.exportJson(id)));
      if (payload is! Map<String, dynamic>) {
        throw const MlResearchException('本機研究樣本格式錯誤。');
      }
      await remote.upload(payload);
      final remaining = prefs.getStringList(queueKey) ?? <String>[];
      remaining.remove(id);
      await prefs.setStringList(queueKey, remaining);
      final synced = prefs.getStringList(_syncedKey) ?? <String>[];
      if (!synced.contains(id)) {
        await prefs.setStringList(_syncedKey, [...synced, id]);
      }
    }
  }
}
