import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../models/custom_rehab_exercise.dart';

typedef SessionValueProvider = String? Function();

class CustomExerciseApiException implements Exception {
  final int? statusCode;
  final String message;

  const CustomExerciseApiException(
    this.message, {
    this.statusCode,
  });

  @override
  String toString() => message;
}

class CustomExerciseApiClient {
  static const _requestTimeout = Duration(seconds: 90);

  final http.Client _httpClient;
  final String _baseUrl;
  final SessionValueProvider _userIdProvider;
  final SessionValueProvider _identityTokenProvider;
  final Duration _timeout;

  CustomExerciseApiClient({
    required String baseUrl,
    required SessionValueProvider userIdProvider,
    required SessionValueProvider identityTokenProvider,
    http.Client? httpClient,
    Duration timeout = _requestTimeout,
  })  : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _userIdProvider = userIdProvider,
        _identityTokenProvider = identityTokenProvider,
        _httpClient = httpClient ?? http.Client(),
        _timeout = timeout;

  Future<List<CustomRehabExercise>> getAllExercises() async {
    final response = await _httpClient
        .get(_collectionUri, headers: _headers())
        .timeout(_timeout);
    _requireSuccess(response, expectedStatusCodes: const {200});

    final decoded = _decodeResponse(response);
    if (decoded is! List) {
      throw const CustomExerciseApiException('伺服器回傳的自訂動作清單格式錯誤');
    }
    try {
      return decoded
          .map(
            (item) => CustomRehabExercise.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
    } on Object catch (error) {
      throw CustomExerciseApiException('自訂動作資料無法解析：$error');
    }
  }

  Future<CustomRehabExercise?> getExercise(String id) async {
    final response = await _httpClient
        .get(_exerciseUri(id), headers: _headers())
        .timeout(_timeout);
    if (response.statusCode == 404) return null;
    _requireSuccess(response, expectedStatusCodes: const {200});
    return _decodeExercise(response);
  }

  Future<CustomRehabExercise> saveExercise(
    CustomRehabExercise exercise,
  ) async {
    final response = await _httpClient
        .put(
          _exerciseUri(exercise.id),
          headers: _headers(),
          body: jsonEncode(exercise.toJson()),
        )
        .timeout(_timeout);
    _requireSuccess(response, expectedStatusCodes: const {200});
    return _decodeExercise(response);
  }

  Future<void> deleteExercise(String id) async {
    final response = await _httpClient
        .delete(_exerciseUri(id), headers: _headers())
        .timeout(_timeout);
    _requireSuccess(response, expectedStatusCodes: const {204});
  }

  Uri get _collectionUri => Uri.parse('$_baseUrl/api/custom-exercises');

  Uri _exerciseUri(String id) => Uri.parse(
        '$_baseUrl/api/custom-exercises/${Uri.encodeComponent(id)}',
      );

  Map<String, String> _headers() {
    final userId = _userIdProvider()?.trim();
    final identityToken = _identityTokenProvider()?.trim();
    if (userId == null || userId.isEmpty) {
      throw const CustomExerciseApiException('找不到登入使用者，請重新登入');
    }
    if (identityToken == null || identityToken.isEmpty) {
      throw const CustomExerciseApiException(
        '目前登入狀態缺少自訂動作授權，請登出後重新登入',
      );
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=UTF-8',
      'X-User-Id': userId,
      'X-Custom-Exercise-Token': identityToken,
    };
  }

  CustomRehabExercise _decodeExercise(http.Response response) {
    final decoded = _decodeResponse(response);
    if (decoded is! Map) {
      throw const CustomExerciseApiException('伺服器回傳的自訂動作格式錯誤');
    }
    try {
      return CustomRehabExercise.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } on Object catch (error) {
      throw CustomExerciseApiException('自訂動作資料無法解析：$error');
    }
  }

  dynamic _decodeResponse(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    try {
      return jsonDecode(body);
    } on FormatException catch (error) {
      throw CustomExerciseApiException('伺服器回傳非預期內容：$error');
    }
  }

  void _requireSuccess(
    http.Response response, {
    required Set<int> expectedStatusCodes,
  }) {
    if (expectedStatusCodes.contains(response.statusCode)) return;

    final body = utf8.decode(response.bodyBytes);
    String? serverMessage;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        serverMessage = decoded['message'] as String;
      }
    } on FormatException {
      serverMessage = body.trim().isEmpty ? null : body.trim();
    }
    throw CustomExerciseApiException(
      serverMessage ?? '自訂動作 API 請求失敗 (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }
}
