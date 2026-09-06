import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import '../account/app_session.dart';
import 'friend_models.dart';

typedef FriendSessionValueProvider = String? Function();

class FriendApiException implements Exception {
  const FriendApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class FriendApiService {
  FriendApiService({
    String baseUrl = ApiConfig.baseUrl,
    http.Client? client,
    FriendSessionValueProvider? userIdProvider,
    FriendSessionValueProvider? identityTokenProvider,
    this.timeout = const Duration(seconds: 90),
  })  : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _client = client ?? http.Client(),
        _ownsClient = client == null,
        _userIdProvider = userIdProvider ?? (() => AppSession.userId),
        _identityTokenProvider =
            identityTokenProvider ?? (() => AppSession.customExerciseToken);

  final String _baseUrl;
  final http.Client _client;
  final bool _ownsClient;
  final FriendSessionValueProvider _userIdProvider;
  final FriendSessionValueProvider _identityTokenProvider;
  final Duration timeout;

  Future<void> sendFriendRequest(String friendCode) async {
    final normalized = friendCode.trim().toUpperCase();
    final response = await _perform(
      () => _client.post(
        _uri('/api/friends/requests'),
        headers: _headers(),
        body: jsonEncode({'friendCode': normalized}),
      ),
    );
    _requireSuccess(response);
  }

  Future<List<FriendRequestItem>> getPendingRequests() async {
    final response = await _perform(
      () => _client.get(
        _uri('/api/friends/requests/pending'),
        headers: _headers(),
      ),
    );
    return _decodeList(response)
        .map((item) => FriendRequestItem.fromJson(_jsonMap(item)))
        .toList(growable: false);
  }

  Future<List<SentFriendRequestItem>> getSentRequests() async {
    final response = await _perform(
      () => _client.get(
        _uri('/api/friends/requests/sent'),
        headers: _headers(),
      ),
    );
    return _decodeList(response)
        .map((item) => SentFriendRequestItem.fromJson(_jsonMap(item)))
        .toList(growable: false);
  }

  Future<void> acceptRequest(String requestId) =>
      _respondToRequest(requestId, 'ACCEPT');

  Future<void> rejectRequest(String requestId) =>
      _respondToRequest(requestId, 'REJECT');

  Future<void> cancelRequest(String requestId) async {
    final response = await _perform(
      () => _client.delete(
        _uri('/api/friends/requests/${Uri.encodeComponent(requestId)}'),
        headers: _headers(),
      ),
    );
    _requireSuccess(response);
  }

  Future<List<FriendItem>> getFriends() async {
    final response = await _perform(
      () => _client.get(_uri('/api/friends'), headers: _headers()),
    );
    return _decodeList(response)
        .map((item) => FriendItem.fromJson(_jsonMap(item)))
        .toList(growable: false);
  }

  Future<void> removeFriend(String friendId) async {
    final response = await _perform(
      () => _client.delete(
        _uri('/api/friends/${Uri.encodeComponent(friendId)}'),
        headers: _headers(),
      ),
    );
    _requireSuccess(response);
  }

  Future<void> _respondToRequest(String requestId, String action) async {
    final response = await _perform(
      () => _client.put(
        _uri(
          '/api/friends/requests/${Uri.encodeComponent(requestId)}/respond',
        ),
        headers: _headers(),
        body: jsonEncode({'action': action}),
      ),
    );
    _requireSuccess(response);
  }

  Future<http.Response> _perform(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(timeout);
    } on FriendApiException {
      rethrow;
    } on TimeoutException {
      throw const FriendApiException('連線逾時，請稍後再試');
    } on http.ClientException {
      throw const FriendApiException('無法連線到伺服器，請稍後再試');
    } on Object {
      throw const FriendApiException('好友服務暫時無法使用，請稍後再試');
    }
  }

  Map<String, String> _headers() {
    final userId = _userIdProvider()?.trim();
    final token = _identityTokenProvider()?.trim();
    if (userId == null || userId.isEmpty || token == null || token.isEmpty) {
      throw const FriendApiException(
        '登入狀態已失效，請重新登入',
        statusCode: 401,
      );
    }
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      'X-User-Id': userId,
      'X-Custom-Exercise-Token': token,
    };
  }

  List<dynamic> _decodeList(http.Response response) {
    _requireSuccess(response);
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is List) return decoded;
    } on FormatException {
      // Converted to a safe UI message below.
    }
    throw const FriendApiException('伺服器回傳好友資料格式錯誤');
  }

  Map<String, dynamic> _jsonMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FriendApiException('伺服器回傳好友資料格式錯誤');
  }

  void _requireSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw FriendApiException(
        '登入狀態已失效，請重新登入',
        statusCode: response.statusCode,
      );
    }
    String? message;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        final value = decoded['message']?.toString().trim();
        if (value != null && value.isNotEmpty) message = value;
      }
    } on FormatException {
      // Never expose raw HTML or transport details.
    }
    throw FriendApiException(
      message ?? '好友操作失敗，請稍後再試',
      statusCode: response.statusCode,
    );
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
