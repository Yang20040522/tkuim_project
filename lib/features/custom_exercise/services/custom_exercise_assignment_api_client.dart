import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../models/custom_exercise_assignment.dart';
import '../../../models/custom_rehab_exercise.dart';
import 'custom_exercise_api_client.dart';

class CustomExerciseAssignmentApiClient {
  static const _requestTimeout = Duration(seconds: 90);

  final http.Client _httpClient;
  final String _baseUrl;
  final SessionValueProvider _userIdProvider;
  final SessionValueProvider _identityTokenProvider;
  final Duration _timeout;

  CustomExerciseAssignmentApiClient({
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

  Future<List<AssignablePatient>> getAssignablePatients() async {
    final response = await _httpClient
        .get(
          Uri.parse('$_baseUrl/api/custom-exercise-assignments/patients'),
          headers: _headers(),
        )
        .timeout(_timeout);
    _requireSuccess(response, const {200});
    return _decodeList(
      response,
      (item) => AssignablePatient.fromJson(item),
      '伺服器回傳的患者清單格式錯誤',
    );
  }

  Future<List<CustomExerciseAssignment>> getExerciseAssignments(
    String exerciseId,
  ) async {
    final response = await _httpClient
        .get(
          Uri.parse(
            '$_baseUrl/api/custom-exercise-assignments/exercises/'
            '${Uri.encodeComponent(exerciseId)}',
          ),
          headers: _headers(),
        )
        .timeout(_timeout);
    _requireSuccess(response, const {200});
    return _decodeList(
      response,
      (item) => CustomExerciseAssignment.fromJson(item),
      '伺服器回傳的指派清單格式錯誤',
    );
  }

  Future<CustomExerciseAssignment> assign(
    String exerciseId,
    String patientId,
  ) async {
    final response = await _httpClient
        .put(
          _assignmentUri(exerciseId, patientId),
          headers: _headers(),
        )
        .timeout(_timeout);
    _requireSuccess(response, const {200});
    return CustomExerciseAssignment.fromJson(_decodeMap(response));
  }

  Future<void> unassign(String exerciseId, String patientId) async {
    final response = await _httpClient
        .delete(
          _assignmentUri(exerciseId, patientId),
          headers: _headers(),
        )
        .timeout(_timeout);
    _requireSuccess(response, const {204});
  }

  Future<List<CustomRehabExercise>> getPatientExercises() async {
    final response = await _httpClient
        .get(
          Uri.parse('$_baseUrl/api/patient/custom-exercises'),
          headers: _headers(),
        )
        .timeout(_timeout);
    _requireSuccess(response, const {200});
    return _decodeList(
      response,
      (item) => CustomRehabExercise.fromJson(item),
      '伺服器回傳的已指派動作清單格式錯誤',
    );
  }

  Future<CustomRehabExercise?> getPatientExercise(String exerciseId) async {
    final response = await _httpClient
        .get(
          Uri.parse(
            '$_baseUrl/api/patient/custom-exercises/'
            '${Uri.encodeComponent(exerciseId)}',
          ),
          headers: _headers(),
        )
        .timeout(_timeout);
    if (response.statusCode == 404) return null;
    _requireSuccess(response, const {200});
    return CustomRehabExercise.fromJson(_decodeMap(response));
  }

  Uri _assignmentUri(String exerciseId, String patientId) => Uri.parse(
        '$_baseUrl/api/custom-exercise-assignments/'
        '${Uri.encodeComponent(exerciseId)}/patients/'
        '${Uri.encodeComponent(patientId)}',
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

  List<T> _decodeList<T>(
    http.Response response,
    T Function(Map<String, dynamic>) parse,
    String invalidMessage,
  ) {
    final decoded = _decode(response);
    if (decoded is! List) {
      throw CustomExerciseApiException(invalidMessage);
    }
    try {
      return decoded
          .map((item) => parse(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false);
    } on Object catch (error) {
      throw CustomExerciseApiException('$invalidMessage：$error');
    }
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    final decoded = _decode(response);
    if (decoded is! Map) {
      throw const CustomExerciseApiException('伺服器回傳資料格式錯誤');
    }
    return Map<String, dynamic>.from(decoded);
  }

  dynamic _decode(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    try {
      return jsonDecode(body);
    } on FormatException catch (error) {
      throw CustomExerciseApiException('伺服器回傳非預期內容：$error');
    }
  }

  void _requireSuccess(http.Response response, Set<int> expected) {
    if (expected.contains(response.statusCode)) return;
    final body = utf8.decode(response.bodyBytes);
    String? message;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        message = decoded['message'] as String;
      }
    } on FormatException {
      message = body.trim().isEmpty ? null : body.trim();
    }
    throw CustomExerciseApiException(
      message ?? '自訂動作指派 API 請求失敗 (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }
}
