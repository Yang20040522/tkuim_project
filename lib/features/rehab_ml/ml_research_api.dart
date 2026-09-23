import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import '../account/app_session.dart';

class MlResearchException implements Exception {
  const MlResearchException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class MlResearchConsent {
  const MlResearchConsent({
    required this.active,
    required this.available,
    required this.currentVersion,
    this.subjectId,
  });
  final bool active;
  final bool available;
  final String currentVersion;
  final String? subjectId;

  factory MlResearchConsent.fromJson(Map<String, dynamic> json) =>
      MlResearchConsent(
        active: json['active'] == true,
        available: json['available'] == true,
        currentVersion: json['currentVersion']?.toString() ?? '',
        subjectId: json['subjectId']?.toString(),
      );
}

abstract class MlResearchRemote {
  Future<MlResearchConsent> getConsent();
  Future<MlResearchConsent> setConsent(bool agree, String version);
  Future<void> upload(Map<String, dynamic> sample);
  Future<List<Map<String, dynamic>>> listSamples({int page = 0});
  Future<Map<String, dynamic>> sampleDetail(String id);
  Future<void> labelSample(String id, String label, String note);
  Future<void> deleteMyData();
}

/// Authenticated, HTTPS-only transport. No account identity or raw payload in logs.
class MlResearchApi implements MlResearchRemote {
  MlResearchApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? ApiConfig.baseUrl).replaceFirst(RegExp(r'/+$'), '');

  final http.Client _client;
  final String _baseUrl;

  Map<String, String> _headers() {
    final id = AppSession.userId?.trim();
    final token = AppSession.customExerciseToken?.trim();
    if (id == null || id.isEmpty || token == null || token.isEmpty) {
      throw const MlResearchException('登入狀態已失效，請重新登入。', statusCode: 401);
    }
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      'X-User-Id': id,
      'X-Custom-Exercise-Token': token,
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$_baseUrl/api/ml-research$path');
    if (uri.scheme != 'https') {
      throw const MlResearchException('研究資料同步需要安全連線。');
    }
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<dynamic> _decode(Future<http.Response> request) async {
    final response = await request.timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MlResearchException(
        response.statusCode == 503
            ? '研究資料服務尚未開放。'
            : response.statusCode == 401 || response.statusCode == 403
                ? '目前沒有存取研究資料的權限。'
                : '研究資料操作失敗，請稍後重試。',
        statusCode: response.statusCode,
      );
    }
    if (response.bodyBytes.isEmpty) return null;
    final value = jsonDecode(utf8.decode(response.bodyBytes));
    if (value is Map<String, dynamic>) return value;
    throw const MlResearchException('研究資料格式錯誤。');
  }

  @override
  Future<MlResearchConsent> getConsent() async => MlResearchConsent.fromJson(
        await _decode(_client.get(_uri('/consent'), headers: _headers()))
            as Map<String, dynamic>,
      );

  @override
  Future<MlResearchConsent> setConsent(bool agree, String version) async =>
      MlResearchConsent.fromJson(await _decode(_client.put(
        _uri('/consent'),
        headers: _headers(),
        body: jsonEncode({'agree': agree, 'version': version}),
      )) as Map<String, dynamic>);

  @override
  Future<void> upload(Map<String, dynamic> sample) async {
    await _decode(_client.post(_uri('/samples'),
        headers: _headers(), body: jsonEncode(sample)));
  }

  @override
  Future<List<Map<String, dynamic>>> listSamples({int page = 0}) async {
    final data = await _decode(_client.get(
      _uri('/samples', {'page': '$page', 'size': '20'}),
      headers: _headers(),
    )) as Map<String, dynamic>;
    return (data['content'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> sampleDetail(String id) async =>
      await _decode(_client.get(_uri('/samples/${Uri.encodeComponent(id)}'),
          headers: _headers())) as Map<String, dynamic>;

  @override
  Future<void> labelSample(String id, String label, String note) async {
    await _decode(_client.put(
      _uri('/samples/${Uri.encodeComponent(id)}/label'),
      headers: _headers(),
      body: jsonEncode({
        'label': label,
        'note': note,
        'labelVersion': 'research-v1',
        'actionDefinitionVersion': 'standing-knee-raise-v1',
      }),
    ));
  }

  @override
  Future<void> deleteMyData() async {
    await _decode(_client.delete(_uri('/my-data'), headers: _headers()));
  }
}
