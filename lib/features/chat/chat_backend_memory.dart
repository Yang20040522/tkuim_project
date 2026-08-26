// lib/features/chat/chat_backend_memory.dart
//
// ChatBackend 的「暫時」實作 — 存在本機 SharedPreferences,
// 不需要任何雲端服務就能先把 UI 串起來、測試流程。
//
// ⚠️ 這是單機模擬:沒有真正的雲端同步,兩支手機互傳訊息
// 互相看不到對方,只適合開發期間先把畫面/流程接起來用。
// 之後接了真的後端,把 ChatBackendMemory 換成
// FirebaseChatBackend / SupabaseChatBackend / RestChatBackend,
// UI 完全不用改。

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_backend.dart';
import 'chat_models.dart';

class ChatBackendMemory implements ChatBackend {
  static const _conversationsKey = 'remote_conversations_v1';
  static const _messagesKeyPrefix = 'remote_messages_v1_';

  final Map<String, StreamController<List<RemoteConversation>>>
      _conversationControllers = {};
  final Map<String, StreamController<List<RemoteChatMessage>>>
      _messageControllers = {};
  final Map<String, StreamController<List<UnreadCount>>> _unreadControllers =
      {};

  List<RemoteConversation> _conversationsCache = [];
  final Map<String, List<RemoteChatMessage>> _messagesCache = {};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();

    final rawConv = prefs.getString(_conversationsKey);
    if (rawConv != null && rawConv.isNotEmpty) {
      final list = jsonDecode(rawConv) as List<dynamic>;
      _conversationsCache = list
          .map((e) => RemoteConversation.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    for (final conv in _conversationsCache) {
      final rawMsgs = prefs.getString('$_messagesKeyPrefix${conv.id}');
      if (rawMsgs != null && rawMsgs.isNotEmpty) {
        final list = jsonDecode(rawMsgs) as List<dynamic>;
        _messagesCache[conv.id] = list
            .map((e) => RemoteChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    _loaded = true;
  }

  Future<void> _persistConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_conversationsCache.map((c) => c.toJson()).toList());
    await prefs.setString(_conversationsKey, raw);
  }

  Future<void> _persistMessages(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final msgs = _messagesCache[conversationId] ?? [];
    final raw = jsonEncode(msgs.map((m) => m.toJson()).toList());
    await prefs.setString('$_messagesKeyPrefix$conversationId', raw);
  }

  void _emitConversations(String myUserId) {
    final ctrl = _conversationControllers[myUserId];
    if (ctrl == null) return;
    final mine = _conversationsCache
        .where((c) => c.participantIds.contains(myUserId))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    ctrl.add(mine);
  }

  void _emitMessages(String conversationId) {
    final ctrl = _messageControllers[conversationId];
    if (ctrl == null) return;
    final msgs = List<RemoteChatMessage>.from(_messagesCache[conversationId] ?? []);
    msgs.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    ctrl.add(msgs);
  }

  void _emitUnread(String myUserId) {
    final ctrl = _unreadControllers[myUserId];
    if (ctrl == null) return;
    final result = <UnreadCount>[];
    for (final conv in _conversationsCache) {
      if (!conv.participantIds.contains(myUserId)) continue;
      final msgs = _messagesCache[conv.id] ?? [];
      final count = msgs.where((m) => m.senderId != myUserId && !m.isRead).length;
      result.add(UnreadCount(conv.id, count));
    }
    ctrl.add(result);
  }

  @override
  Future<String> getOrCreateConversation({
    required String myUserId,
    required String otherUserId,
    required ConversationType type,
  }) async {
    await _ensureLoaded();

    final existing = _conversationsCache.where((c) =>
        c.participantIds.contains(myUserId) &&
        c.participantIds.contains(otherUserId));

    if (existing.isNotEmpty) return existing.first.id;

    final now = DateTime.now();
    final conv = RemoteConversation(
      id: now.microsecondsSinceEpoch.toString(),
      type: type,
      participantIds: [myUserId, otherUserId],
      updatedAt: now,
    );
    _conversationsCache.add(conv);
    _messagesCache[conv.id] = [];
    await _persistConversations();
    _emitConversations(myUserId);
    _emitConversations(otherUserId);
    return conv.id;
  }

  @override
  Stream<List<RemoteConversation>> watchConversations(String myUserId) {
    final ctrl = _conversationControllers.putIfAbsent(
        myUserId, () => StreamController<List<RemoteConversation>>.broadcast());
    _ensureLoaded().then((_) => _emitConversations(myUserId));
    return ctrl.stream;
  }

  @override
  Stream<List<RemoteChatMessage>> watchMessages(String conversationId) {
    final ctrl = _messageControllers.putIfAbsent(conversationId,
        () => StreamController<List<RemoteChatMessage>>.broadcast());
    _ensureLoaded().then((_) => _emitMessages(conversationId));
    return ctrl.stream;
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    await _ensureLoaded();
    final msg = RemoteChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      conversationId: conversationId,
      senderId: senderId,
      text: text,
      sentAt: DateTime.now(),
    );
    _messagesCache.putIfAbsent(conversationId, () => []).add(msg);
    await _persistMessages(conversationId);

    final convIdx = _conversationsCache.indexWhere((c) => c.id == conversationId);
    if (convIdx >= 0) {
      final conv = _conversationsCache[convIdx];
      _conversationsCache[convIdx] = conv.copyWith(
        lastMessageText: text,
        lastMessageAt: msg.sentAt,
        updatedAt: msg.sentAt,
      );
      await _persistConversations();
      for (final uid in conv.participantIds) {
        _emitConversations(uid);
        _emitUnread(uid);
      }
    }
    _emitMessages(conversationId);
  }

  @override
  Future<void> markAsRead({
    required String conversationId,
    required String myUserId,
  }) async {
    await _ensureLoaded();
    final msgs = _messagesCache[conversationId];
    if (msgs == null) return;

    var changed = false;
    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      if (m.senderId != myUserId && !m.isRead) {
        msgs[i] = m.copyWith(readAt: DateTime.now());
        changed = true;
      }
    }
    if (changed) {
      await _persistMessages(conversationId);
      _emitMessages(conversationId);
      _emitUnread(myUserId);
    }
  }

  @override
  Stream<List<UnreadCount>> watchUnreadCounts(String myUserId) {
    final ctrl = _unreadControllers.putIfAbsent(
        myUserId, () => StreamController<List<UnreadCount>>.broadcast());
    _ensureLoaded().then((_) => _emitUnread(myUserId));
    return ctrl.stream;
  }

  @override
  void dispose() {
    for (final c in _conversationControllers.values) {
      c.close();
    }
    for (final c in _messageControllers.values) {
      c.close();
    }
    for (final c in _unreadControllers.values) {
      c.close();
    }
  }
}