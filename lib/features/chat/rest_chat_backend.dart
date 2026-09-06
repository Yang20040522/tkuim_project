import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import '../account/app_session.dart';
import 'chat_backend.dart';
import 'chat_models.dart';

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
class RestChatBackend implements ChatBackend {
  RestChatBackend({
    String baseUrl = ApiConfig.baseUrl,
    http.Client? httpClient,
    ChatSessionValueProvider? userIdProvider,
    ChatSessionValueProvider? identityTokenProvider,
    this.requestTimeout = const Duration(seconds: 30),
    this.conversationPollInterval = const Duration(seconds: 3),
    this.messagePollInterval = const Duration(seconds: 2),
    this.unreadPollInterval = const Duration(seconds: 3),
  })  : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _client = httpClient ?? http.Client(),
        _ownsClient = httpClient == null,
        _userIdProvider = userIdProvider ?? (() => AppSession.userId),
        _identityTokenProvider =
            identityTokenProvider ?? (() => AppSession.customExerciseToken) {
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
          ),
        )
        .stream;
  }

  @override
  void refresh() {
    _ensureNotDisposed();
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

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
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
  _RefreshChannel({required this.fetch}) {
    _controller = StreamController<T>.broadcast(
      onListen: _start,
    );
  }

  final Future<T> Function() fetch;
  late final StreamController<T> _controller;
  bool _fetching = false;
  bool _closed = false;

  Stream<T> get stream => _controller.stream;

  void _start() {
    if (_closed) return;
    refresh();
  }

  void refresh() {
    if (_closed || _fetching || !_controller.hasListener) return;
    _fetching = true;
    fetch().then((value) {
      if (!_closed) {
        _controller.add(value);
      }
    }).catchError((Object error, StackTrace stackTrace) {
      if (!_closed) {
        _controller.addError(error, stackTrace);
      }
    }).whenComplete(() {
      _fetching = false;
    });
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _controller.close();
  }
}
