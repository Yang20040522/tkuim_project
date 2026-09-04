import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../models/assignable_exercise.dart';
import '../../../models/custom_exercise_assignment.dart';
import '../../../models/custom_rehab_exercise.dart';
import 'custom_exercise_api_client.dart';

class UnifiedExerciseAssignmentApiClient {
  static const _requestTimeout = Duration(seconds: 90);

  final http.Client _httpClient;
  final String _baseUrl;
  final SessionValueProvider _userIdProvider;
  final SessionValueProvider _identityTokenProvider;
  final Duration _timeout;

  UnifiedExerciseAssignmentApiClient({
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
    return _decodeList(response, AssignablePatient.fromJson);
  }

  Future<List<AssignableExercise>> getAssignableExercises(
    String patientId,
  ) async {
    final uri = Uri.parse('$_baseUrl/api/assignable-exercises').replace(
      queryParameters: {'patientId': patientId},
    );
    final response =
        await _httpClient.get(uri, headers: _headers()).timeout(_timeout);
    _requireSuccess(response, const {200});
    return _decodeList(response, AssignableExercise.fromJson);
  }

  Future<AssignableExercise> assign(
    AssignableExercise exercise,
    String patientId,
  ) async {
    final response = await _httpClient
        .put(_assignmentUri(exercise, patientId), headers: _headers())
        .timeout(_timeout);
    _requireSuccess(response, const {200});
    return AssignableExercise.fromJson(_decodeMap(response));
  }

  Future<void> unassign(
    AssignableExercise exercise,
    String patientId,
  ) async {
    final response = await _httpClient
        .delete(_assignmentUri(exercise, patientId), headers: _headers())
        .timeout(_timeout);
    _requireSuccess(response, const {204});
  }

  Future<List<AssignableExercise>> getPatientAssignedExercises() async {
    final response = await _httpClient
        .get(
          Uri.parse('$_baseUrl/api/patient/assigned-exercises'),
          headers: _headers(),
        )
        .timeout(_timeout);
    _requireSuccess(response, const {200});
    return _decodeList(response, AssignableExercise.fromJson);
  }

  Future<CustomRehabExercise?> getPatientCustomExercise(
    String exerciseId,
  ) async {
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

  Uri _assignmentUri(
    AssignableExercise exercise,
    String patientId,
  ) {
    return Uri.parse(
      '$_baseUrl/api/assignable-exercises/'
      '${exercise.type.apiValue}/${Uri.encodeComponent(exercise.id)}/patients/'
      '${Uri.encodeComponent(patientId)}',
    );
  }

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
  ) {
    final decoded = _decode(response);
    if (decoded is! List) {
      throw const CustomExerciseApiException('伺服器回傳清單格式錯誤');
    }
    try {
      return decoded
          .map((item) => parse(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false);
    } on Object catch (error) {
      throw CustomExerciseApiException('伺服器回傳資料格式錯誤：$error');
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
      message ?? '復健動作指派 API 請求失敗 (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }
}
