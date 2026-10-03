import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/widgets.dart';

import '../../core/api_config.dart';
import '../account/app_session.dart';
import 'chat_backend.dart';
import 'chat_models.dart';
import 'chat_realtime_connection.dart';

typedef ChatSessionValueProvider = String? Function();

class ChatApiException implements Exception {
  const ChatApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// REST implementation refreshed on subscription and explicit user/lifecycle
/// events. It intentionally has no continuous polling timer.
class RestChatBackend with WidgetsBindingObserver implements ChatBackend {
  RestChatBackend({
    String baseUrl = ApiConfig.baseUrl,
    http.Client? httpClient,
    ChatSessionValueProvider? userIdProvider,
    ChatSessionValueProvider? identityTokenProvider,
    this.requestTimeout = const Duration(seconds: 30),
    this.conversationPollInterval = const Duration(seconds: 3),
    this.messagePollInterval = const Duration(seconds: 2),
    this.unreadPollInterval = const Duration(seconds: 3),
    bool? realtimeEnabled,
    ChatRealtimeTransportFactory? realtimeTransportFactory,
  })  : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _client = httpClient ?? http.Client(),
        _ownsClient = httpClient == null,
        _userIdProvider = userIdProvider ?? (() => AppSession.userId),
        _identityTokenProvider =
            identityTokenProvider ?? (() => AppSession.customExerciseToken),
        _realtimeEnabled = realtimeEnabled ??
            (httpClient == null || realtimeTransportFactory != null),
        _realtimeTransportFactory =
            realtimeTransportFactory ?? StompChatTransport.new {
    _sessionUserId = _userIdProvider()?.trim();
    _sessionToken = _identityTokenProvider()?.trim();
    AppSession.changes.addListener(_sessionChanged);
    if (conversationPollInterval < const Duration(seconds: 1) ||
        messagePollInterval < const Duration(seconds: 1) ||
        unreadPollInterval < const Duration(seconds: 1)) {
      throw ArgumentError('聊天室 polling 間隔不可小於 1 秒');
    }
  }

  final String _baseUrl;
  final http.Client _client;
  final bool _ownsClient;
  final ChatSessionValueProvider _userIdProvider;
  final ChatSessionValueProvider _identityTokenProvider;
  final Duration requestTimeout;
  final Duration conversationPollInterval;
  final Duration messagePollInterval;
  final Duration unreadPollInterval;
  final bool _realtimeEnabled;
  final ChatRealtimeTransportFactory _realtimeTransportFactory;
  late final String? _sessionUserId;
  late final String? _sessionToken;
  ChatRealtimeConnection? _realtime;
  bool _observingLifecycle = false;
  bool _foreground = true;

  // Interval values remain source-compatible with existing construction sites,
  // but no channel schedules a periodic timer.
  final Map<String, _RefreshChannel<List<RemoteConversation>>>
      _conversationChannels = {};
  final Map<String, _RefreshChannel<List<RemoteChatMessage>>> _messageChannels =
      {};
  final Map<String, _RefreshChannel<List<UnreadCount>>> _unreadChannels = {};
  bool _disposed = false;

  @override
  Future<List<ChatContact>> getContacts() async {
    final response = await _client
        .get(_uri('/api/chat/contacts'), headers: _headers())
        .timeout(requestTimeout);
    final list = _decodeList(response, const {200});
    return list
        .map((item) => ChatContact.fromJson(_jsonMap(item)))
        .toList(growable: false);
  }

  @override
  Future<String> getOrCreateConversation({
    required String myUserId,
    required String otherUserId,
    required ConversationType type,
  }) async {
    final response = await _client
        .post(
          _uri('/api/chat/conversations'),
          headers: _headers(expectedUserId: myUserId),
          body: jsonEncode({
            'otherUserId': otherUserId,
            'type': type.name,
          }),
        )
        .timeout(requestTimeout);
    final conversation = RemoteConversation.fromJson(
      _decodeMap(response, const {200}),
    );
    _conversationChannels[myUserId]?.refresh();
    return conversation.id;
  }

  @override
  Stream<List<RemoteConversation>> watchConversations(String myUserId) {
    _ensureNotDisposed();
    return _conversationChannels
        .putIfAbsent(
          myUserId,
          () => _RefreshChannel(
            fetch: () => _fetchConversations(myUserId),
            listenersChanged: _listenersChanged,
            canDeliver: _canUseSession,
          ),
        )
        .stream;
  }

  @override
  Stream<List<RemoteChatMessage>> watchMessages(String conversationId) {
    _ensureNotDisposed();
    return _messageChannels
        .putIfAbsent(
          conversationId,
          () => _RefreshChannel(
            fetch: () => _fetchMessages(conversationId),
            listenersChanged: _listenersChanged,
            canDeliver: _canUseSession,
          ),
        )
        .stream;
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    final response = await _client
        .post(
          _uri(
            '/api/chat/conversations/'
            '${Uri.encodeComponent(conversationId)}/messages',
          ),
          headers: _headers(expectedUserId: senderId),
          body: jsonEncode({'text': text}),
        )
        .timeout(requestTimeout);
    _requireSuccess(response, const {201});
    _messageChannels[conversationId]?.refresh();
    _refreshCurrentUserLists();
  }

  @override
  Future<void> markAsRead({
    required String conversationId,
    required String myUserId,
  }) async {
    final response = await _client
        .put(
          _uri(
            '/api/chat/conversations/'
            '${Uri.encodeComponent(conversationId)}/read',
          ),
          headers: _headers(expectedUserId: myUserId),
        )
        .timeout(requestTimeout);
    _requireSuccess(response, const {204});
    _messageChannels[conversationId]?.refresh();
    _unreadChannels[myUserId]?.refresh();
  }

  @override
  Stream<List<UnreadCount>> watchUnreadCounts(String myUserId) {
    _ensureNotDisposed();
    return _unreadChannels
        .putIfAbsent(
          myUserId,
          () => _RefreshChannel(
            fetch: () => _fetchUnreadCounts(myUserId),
            listenersChanged: _listenersChanged,
            canDeliver: _canUseSession,
          ),
        )
        .stream;
  }

  @override
  void refresh() {
    _ensureNotDisposed();
    _listenersChanged();
    for (final channel in _conversationChannels.values) {
      channel.refresh();
    }
    for (final channel in _messageChannels.values) {
      channel.refresh();
    }
    for (final channel in _unreadChannels.values) {
      channel.refresh();
    }
  }

  Future<List<RemoteConversation>> _fetchConversations(
    String myUserId,
  ) async {
    final response = await _client
        .get(
          _uri('/api/chat/conversations'),
          headers: _headers(expectedUserId: myUserId),
        )
        .timeout(requestTimeout);
    return _decodeList(response, const {200})
        .map((item) => RemoteConversation.fromJson(_jsonMap(item)))
        .toList(growable: false);
  }

  Future<List<RemoteChatMessage>> _fetchMessages(
    String conversationId,
  ) async {
    final response = await _client
        .get(
          _uri(
            '/api/chat/conversations/'
            '${Uri.encodeComponent(conversationId)}/messages',
          ),
          headers: _headers(),
        )
        .timeout(requestTimeout);
    return _decodeList(response, const {200})
        .map((item) => RemoteChatMessage.fromJson(_jsonMap(item)))
        .toList(growable: false);
  }

  Future<List<UnreadCount>> _fetchUnreadCounts(String myUserId) async {
    final response = await _client
        .get(
          _uri('/api/chat/unread-counts'),
          headers: _headers(expectedUserId: myUserId),
        )
        .timeout(requestTimeout);
    return _decodeList(response, const {200})
        .map((item) => UnreadCount.fromJson(_jsonMap(item)))
        .toList(growable: false);
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Map<String, String> _headers({String? expectedUserId}) {
    _ensureNotDisposed();
    final userId = _userIdProvider()?.trim();
    final token = _identityTokenProvider()?.trim();
    if (userId == null || userId.isEmpty) {
      throw const ChatApiException(
        '找不到登入使用者，請重新登入',
        statusCode: 401,
      );
    }
    if (expectedUserId != null && expectedUserId.trim() != userId) {
      throw const ChatApiException(
        '聊天室登入身份不一致',
        statusCode: 403,
      );
    }
    if (token == null || token.isEmpty) {
      throw const ChatApiException(
        '登入授權已失效，請重新登入',
        statusCode: 401,
      );
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=UTF-8',
      'X-User-Id': userId,
      'X-Custom-Exercise-Token': token,
    };
  }

  List<dynamic> _decodeList(http.Response response, Set<int> expected) {
    _requireSuccess(response, expected);
    final decoded = _decodeBody(response);
    if (decoded is! List) {
      throw const ChatApiException('伺服器回傳聊天室清單格式錯誤');
    }
    return decoded;
  }

  Map<String, dynamic> _decodeMap(
    http.Response response,
    Set<int> expected,
  ) {
    _requireSuccess(response, expected);
    return _jsonMap(_decodeBody(response));
  }

  dynamic _decodeBody(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (error) {
      throw ChatApiException('伺服器回傳非預期內容：$error');
    }
  }

  Map<String, dynamic> _jsonMap(dynamic value) {
    if (value is! Map) {
      throw const ChatApiException('伺服器回傳聊天室資料格式錯誤');
    }
    return Map<String, dynamic>.from(value);
  }

  void _requireSuccess(http.Response response, Set<int> expected) {
    if (expected.contains(response.statusCode)) return;
    String? message;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        message = decoded['message']?.toString();
      }
    } on FormatException {
      // The status code and a safe fallback are enough for the UI.
    }
    throw ChatApiException(
      message ?? '聊天室 API 請求失敗 (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  void _refreshCurrentUserLists() {
    final userId = _userIdProvider()?.trim();
    if (userId == null || userId.isEmpty) return;
    _conversationChannels[userId]?.refresh();
    _unreadChannels[userId]?.refresh();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw const ChatApiException('聊天室連線已關閉');
    }
  }

  bool _canUseSession() =>
      !_disposed &&
      _foreground &&
      _sessionUserId == _userIdProvider()?.trim() &&
      _sessionToken == _identityTokenProvider()?.trim();

  void _sessionChanged() {
    if (_sessionUserId != _userIdProvider()?.trim() ||
        _sessionToken != _identityTokenProvider()?.trim()) {
      dispose();
    }
  }

  void _listenersChanged() {
    if (!_realtimeEnabled ||
        !_canUseSession() ||
        _sessionUserId == null ||
        _sessionToken == null ||
        _sessionToken!.isEmpty) {
      return;
    }
    final listening = _conversationChannels.values.any((c) => c.hasListener) ||
        _messageChannels.values.any((c) => c.hasListener) ||
        _unreadChannels.values.any((c) => c.hasListener);
    if (!listening) {
      _realtime?.pause();
      return;
    }
    if (!_observingLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _observingLifecycle = true;
      _foreground = WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (!_foreground) return;
    }
    _realtime ??= ChatRealtimeConnection(
      url: ChatRealtimeConnection.urlFromBase(_baseUrl),
      headers: {
        'X-User-Id': _sessionUserId!,
        'X-Custom-Exercise-Token': _sessionToken!
      },
      isCurrentSession: _canUseSession,
      transportFactory: _realtimeTransportFactory,
      onConnected: refresh,
      onEvent: (event) {
        // No contact fetch and no queries for unobserved conversation channels.
        _messageChannels[event.conversationId]?.refresh();
        if (event.type != 'MESSAGE_READ') {
          _conversationChannels[_sessionUserId]?.refresh();
        }
        _unreadChannels[_sessionUserId]?.refresh();
      },
    );
    _realtime!.resume();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _realtime?.pause();
      return;
    }
    if (!_disposed) refresh();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    AppSession.changes.removeListener(_sessionChanged);
    if (_observingLifecycle) WidgetsBinding.instance.removeObserver(this);
    _realtime?.dispose();
    for (final channel in _conversationChannels.values) {
      unawaited(channel.close());
    }
    for (final channel in _messageChannels.values) {
      unawaited(channel.close());
    }
    for (final channel in _unreadChannels.values) {
      unawaited(channel.close());
    }
    if (_ownsClient) {
      _client.close();
    }
  }
}

class _RefreshChannel<T> {
  _RefreshChannel(
      {required this.fetch,
      required this.listenersChanged,
      required this.canDeliver}) {
    _controller = StreamController<T>.broadcast(
      onListen: _start,
      onCancel: listenersChanged,
    );
  }

  final Future<T> Function() fetch;
  final void Function() listenersChanged;
  final bool Function() canDeliver;
  late final StreamController<T> _controller;
  bool _fetching = false;
  bool _closed = false;
  bool _dirty = false;

  Stream<T> get stream => _controller.stream;
  bool get hasListener => !_closed && _controller.hasListener;

  void _start() {
    if (_closed) return;
    refresh();
    // putIfAbsent must finish before we count listeners in the owner's map.
    scheduleMicrotask(listenersChanged);
  }

  void refresh() {
    if (_closed || !_controller.hasListener || !canDeliver()) return;
    if (_fetching) {
      _dirty = true;
      return;
    }
    _fetching = true;
    _dirty = false;
    fetch().then((value) {
      if (!_closed && canDeliver()) {
        _controller.add(value);
      }
    }).catchError((Object error, StackTrace stackTrace) {
      if (!_closed && canDeliver()) {
        _controller.addError(error, stackTrace);
      }
    }).whenComplete(() {
      _fetching = false;
      if (_dirty) refresh();
    });
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _controller.close();
  }
}
