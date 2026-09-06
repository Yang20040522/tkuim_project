import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../models/training_session_result.dart';
import '../../custom_exercise/services/custom_exercise_api_client.dart';
import '../repositories/training_result_repository.dart';

class TrainingResultApiClient implements TrainingResultRepository {
  TrainingResultApiClient({
    required String baseUrl,
    required SessionValueProvider userIdProvider,
    required SessionValueProvider identityTokenProvider,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 90),
  })  : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _userIdProvider = userIdProvider,
        _identityTokenProvider = identityTokenProvider,
        _httpClient = httpClient ?? http.Client(),
        _timeout = timeout;

  final String _baseUrl;
  final SessionValueProvider _userIdProvider;
  final SessionValueProvider _identityTokenProvider;
  final http.Client _httpClient;
  final Duration _timeout;

  @override
  Future<TrainingSessionResult> save(TrainingSessionResult result) async {
    final response = await _httpClient
        .post(
          Uri.parse('$_baseUrl/api/training-results'),
          headers: _headers(),
          body: jsonEncode(result.toRequestJson()),
        )
        .timeout(_timeout);
    _requireSuccess(response, const {200, 201});
    return TrainingSessionResult.fromJson(_decodeMap(response));
  }

  @override
  Future<List<TrainingSessionResult>> getMyResults() =>
      _get('/api/training-results/me');

  @override
  Future<
      List<
          TrainingSessionResult>> getPatientResults(String patientId) => _get(
      '/api/therapist/patients/${Uri.encodeComponent(patientId)}/training-results');

  Future<List<TrainingSessionResult>> _get(String path) async {
    final response = await _httpClient
        .get(Uri.parse('$_baseUrl$path'), headers: _headers())
        .timeout(_timeout);
    _requireSuccess(response, const {200});
    final decoded = _decode(response);
    if (decoded is! List) {
      throw const CustomExerciseApiException('伺服器回傳訓練紀錄格式錯誤');
    }
    try {
      return decoded
          .map((item) => TrainingSessionResult.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(growable: false);
    } on Object catch (error) {
      throw CustomExerciseApiException('訓練紀錄無法解析：$error');
    }
  }

  Map<String, String> _headers() {
    final userId = _userIdProvider()?.trim();
    final token = _identityTokenProvider()?.trim();
    if (userId == null || userId.isEmpty || token == null || token.isEmpty) {
      throw const CustomExerciseApiException('登入授權已失效，請重新登入');
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=UTF-8',
      'X-User-Id': userId,
      'X-Custom-Exercise-Token': token,
    };
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    final decoded = _decode(response);
    if (decoded is! Map) {
      throw const CustomExerciseApiException('伺服器回傳訓練結果格式錯誤');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Object? _decode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const CustomExerciseApiException('伺服器回傳非預期內容');
    }
  }

  void _requireSuccess(http.Response response, Set<int> expected) {
    if (expected.contains(response.statusCode)) return;
    String? message;
    try {
      final decoded = _decode(response);
      if (decoded is Map && decoded['message'] is String) {
        message = decoded['message'] as String;
      }
    } on Object {
      // Use the safe fallback below.
    }
    throw CustomExerciseApiException(
      message ?? '訓練結果 API 請求失敗 (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }
}
