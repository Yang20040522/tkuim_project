import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../models/therapist_patient.dart';
import '../../custom_exercise/services/custom_exercise_api_client.dart';

class TherapistPatientApiClient {
  static const _requestTimeout = Duration(seconds: 90);

  final http.Client _httpClient;
  final String _baseUrl;
  final SessionValueProvider _userIdProvider;
  final SessionValueProvider _identityTokenProvider;
  final Duration _timeout;

  TherapistPatientApiClient({
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

  Future<List<TherapistPatient>> getPatients() async {
    final response = await _httpClient
        .get(_patientsUri, headers: _headers())
        .timeout(_timeout);
    _requireSuccess(response, const {200});
    final decoded = _decode(response);
    if (decoded is! List) {
      throw const CustomExerciseApiException('伺服器回傳患者清單格式錯誤');
    }
    try {
      return decoded
          .map(
            (item) => TherapistPatient.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
    } on Object catch (error) {
      throw CustomExerciseApiException('患者綁定資料無法解析：$error');
    }
  }

  Future<TherapistPatientPreview> lookupPatient(String bindingCode) async {
    final uri = Uri.parse('$_baseUrl/api/therapist/patients/lookup').replace(
      queryParameters: {'bindingCode': bindingCode.trim()},
    );
    final response =
        await _httpClient.get(uri, headers: _headers()).timeout(_timeout);
    _requireSuccess(response, const {200});
    return TherapistPatientPreview.fromJson(_decodeMap(response));
  }

  Future<TherapistPatient> bindPatient(String bindingCode) async {
    final response = await _httpClient
        .post(
          Uri.parse('$_baseUrl/api/therapist/patients/bind'),
          headers: _headers(),
          body: jsonEncode({'bindingCode': bindingCode.trim()}),
        )
        .timeout(_timeout);
    _requireSuccess(response, const {200});
    return TherapistPatient.fromJson(_decodeMap(response));
  }

  Future<void> unbindPatient(String patientId) async {
    final response = await _httpClient
        .delete(
          Uri.parse(
            '$_baseUrl/api/therapist/patients/'
            '${Uri.encodeComponent(patientId)}',
          ),
          headers: _headers(),
        )
        .timeout(_timeout);
    _requireSuccess(response, const {204});
  }

  Uri get _patientsUri => Uri.parse('$_baseUrl/api/therapist/patients');

  Map<String, String> _headers() {
    final userId = _userIdProvider()?.trim();
    final identityToken = _identityTokenProvider()?.trim();
    if (userId == null || userId.isEmpty) {
      throw const CustomExerciseApiException('找不到登入使用者，請重新登入');
    }
    if (identityToken == null || identityToken.isEmpty) {
      throw const CustomExerciseApiException(
        '目前登入狀態缺少患者管理授權，請登出後重新登入',
      );
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=UTF-8',
      'X-User-Id': userId,
      'X-Custom-Exercise-Token': identityToken,
    };
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    final decoded = _decode(response);
    if (decoded is! Map) {
      throw const CustomExerciseApiException('伺服器回傳患者資料格式錯誤');
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
      message ?? '患者管理 API 請求失敗 (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }
}
