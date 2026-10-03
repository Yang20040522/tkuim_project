import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import '../account/app_session.dart';

class MlResearchException implements Exception {
  const MlResearchException(this.message, {this.statusCode, this.code});
  final String message;
  final int? statusCode;
  final String? code;

  static const _messages = <String, String>{
    'RESEARCH_COLLECTION_NOT_ENABLED': '研究服務尚未開放；本機樣本仍可保存。',
    'RESEARCH_CONSENT_VERSION_UNSET': '研究同意版本尚未設定；請聯絡研究團隊。',
    'RESEARCH_RETENTION_UNSET': '研究資料保存政策尚未核准或尚未生效；暫時無法啟用雲端同步。',
    'CONSENT_VERSION_MISMATCH': '研究同意版本已更新，請重新開啟研究資料頁後再確認同意。',
    'RESEARCH_AUTH_REQUIRED': '登入狀態已失效，請重新登入。',
    'NETWORK_ERROR': '研究服務連線失敗，請檢查網路後再試；本機樣本仍可保存。',
    'NETWORK_TIMEOUT': '研究服務連線逾時，請稍後再試；本機樣本仍可保存。',
    'INVALID_RESPONSE': '研究服務回應格式錯誤，請稍後再試。',
  };

  factory MlResearchException.fromResponse(int status, [dynamic body]) {
    String? code;
    if (body is Map) {
      for (final field in ['code', 'message', 'detail']) {
        final candidate = body[field];
        // Never pass through arbitrary server text (it may contain identifiers).
        if (candidate is String && _messages.containsKey(candidate)) {
          code = candidate;
          break;
        }
      }
    }
    return MlResearchException(
      _messages[code] ??
          (status == 401
              ? '登入狀態已失效，請重新登入。'
              : status == 403
                  ? '目前沒有存取研究資料的權限。'
                  : status == 503
                      ? _messages['RESEARCH_COLLECTION_NOT_ENABLED']!
                      : '研究資料操作失敗（HTTP $status），請稍後重試。'),
      statusCode: status,
      code: code,
    );
  }

  factory MlResearchException.unavailable(String? reason) =>
      MlResearchException.fromResponse(503, {'code': reason});

  static String safeMessage(Object error) => error is MlResearchException
      ? error.message
      : error is TimeoutException
          ? _messages['NETWORK_TIMEOUT']!
          : error is http.ClientException
              ? _messages['NETWORK_ERROR']!
              : '研究資料操作失敗，請稍後重試；本機樣本仍可保存。';
  @override
  String toString() => message;
}

class MlResearchConsent {
  const MlResearchConsent({
    required this.active,
    required this.available,
    required this.currentVersion,
    this.subjectId,
    this.unavailableReason,
  });
  final bool active;
  final bool available;
  final String currentVersion;
  final String? subjectId;
  final String? unavailableReason;

  factory MlResearchConsent.fromJson(Map<String, dynamic> json) =>
      MlResearchConsent(
        active: json['active'] == true,
        available: json['available'] == true,
        currentVersion: json['currentVersion']?.toString() ?? '',
        subjectId: json['subjectId']?.toString(),
        unavailableReason: json['unavailableReason']?.toString(),
      );
}

abstract class MlResearchRemote {
  Future<MlResearchConsent> getConsent();
  Future<MlResearchConsent> setConsent(bool agree, String version);
  Future<void> upload(Map<String, dynamic> sample);
  Future<List<Map<String, dynamic>>> listSamples({int page = 0});
  Future<Map<String, dynamic>> sampleDetail(String id);
  Future<void> labelSample(String id, String label, String note);
  Future<Map<String, dynamic>> authority();
  Future<Map<String, dynamic>> requestReviewAccess();
  Future<List<Map<String, dynamic>>> reviewQueue();
  Future<Map<String, dynamic>> submitLabel(String id);
  Future<Map<String, dynamic>> reviewLabel(
      String id, bool approve, String note);
  Future<Map<String, dynamic>> managementStats();
  Future<List<Map<String, dynamic>>> pendingReviewRequests();
  Future<void> decideReviewRequest(int requestId, bool approve);
  Future<void> setResearchGrant(int userId,
      {required bool canAnnotate,
      required bool canReview,
      required bool canManage});
  Future<Uint8List> exportApproved();
  Future<List<Map<String, dynamic>>> retentionPolicies();
  Future<void> createRetentionPolicy(
      {required String version,
      required int retentionDays,
      required DateTime effectiveAt,
      required String approvalReference});
  Future<int> processExpiredSamples();
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
      throw const MlResearchException('登入狀態已失效，請重新登入。',
          statusCode: 401, code: 'RESEARCH_AUTH_REQUIRED');
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
    final http.Response response;
    try {
      response = await request.timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const MlResearchException('研究服務連線逾時，請稍後再試；本機樣本仍可保存。',
          code: 'NETWORK_TIMEOUT');
    } on http.ClientException {
      throw const MlResearchException('研究服務連線失敗，請檢查網路後再試；本機樣本仍可保存。',
          code: 'NETWORK_ERROR');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      dynamic errorBody;
      try {
        errorBody = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {/* Proxy HTML is not a trusted API error. */}
      throw MlResearchException.fromResponse(response.statusCode, errorBody);
    }
    if (response.bodyBytes.isEmpty) return null;
    final dynamic value;
    try {
      value = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const MlResearchException('研究服務回應格式錯誤，請稍後再試。',
          code: 'INVALID_RESPONSE');
    }
    if (value is Map<String, dynamic> || value is List<dynamic>) return value;
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
  Future<Map<String, dynamic>> authority() async =>
      await _decode(_client.get(_uri('/authority/me'), headers: _headers()))
          as Map<String, dynamic>;

  @override
  Future<Map<String, dynamic>> requestReviewAccess() async => await _decode(
          _client.post(_uri('/authority/review-request'), headers: _headers()))
      as Map<String, dynamic>;

  @override
  Future<List<Map<String, dynamic>>> reviewQueue() async {
    final data =
        await _decode(_client.get(_uri('/review-queue'), headers: _headers()))
            as Map<String, dynamic>;
    return (data['content'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> submitLabel(String id) async =>
      await _decode(_client.post(
        _uri('/samples/${Uri.encodeComponent(id)}/label/submit'),
        headers: _headers(),
      )) as Map<String, dynamic>;

  @override
  Future<Map<String, dynamic>> reviewLabel(
          String id, bool approve, String note) async =>
      await _decode(_client.post(
        _uri('/samples/${Uri.encodeComponent(id)}/label/review'),
        headers: _headers(),
        body: jsonEncode({'approve': approve, 'note': note}),
      )) as Map<String, dynamic>;

  @override
  Future<Map<String, dynamic>> managementStats() async =>
      await _decode(_client.get(_uri('/management/stats'), headers: _headers()))
          as Map<String, dynamic>;

  @override
  Future<List<Map<String, dynamic>>> pendingReviewRequests() async {
    final data = await _decode(_client.get(_uri('/authority/review-requests'),
        headers: _headers())) as List<dynamic>;
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  @override
  Future<void> decideReviewRequest(int requestId, bool approve) async {
    await _decode(_client.put(_uri('/authority/review-requests/$requestId'),
        headers: _headers(), body: jsonEncode({'approve': approve})));
  }

  @override
  Future<void> setResearchGrant(int userId,
      {required bool canAnnotate,
      required bool canReview,
      required bool canManage}) async {
    await _decode(_client.put(_uri('/authority/grants/$userId'),
        headers: _headers(),
        body: jsonEncode({
          'canAnnotate': canAnnotate,
          'canReview': canReview,
          'canManage': canManage,
        })));
  }

  @override
  Future<Uint8List> exportApproved() async {
    final response = await _client
        .get(_uri('/management/export'), headers: _headers())
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200 ||
        response.headers['content-type']?.contains('application/zip') != true) {
      throw MlResearchException('已審核資料匯出失敗，請確認授權與資料狀態。',
          statusCode: response.statusCode);
    }
    return response.bodyBytes;
  }

  @override
  Future<List<Map<String, dynamic>>> retentionPolicies() async {
    final data = await _decode(
            _client.get(_uri('/management/retention'), headers: _headers()))
        as List<dynamic>;
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  @override
  Future<void> createRetentionPolicy(
      {required String version,
      required int retentionDays,
      required DateTime effectiveAt,
      required String approvalReference}) async {
    await _decode(_client.post(_uri('/management/retention'),
        headers: _headers(),
        body: jsonEncode({
          'policyVersion': version,
          'retentionDays': retentionDays,
          'effectiveAt': effectiveAt.toUtc().toIso8601String(),
          'approvalReference': approvalReference,
        })));
  }

  @override
  Future<int> processExpiredSamples() async {
    final data = await _decode(_client.post(
        _uri('/management/retention/process-expired'),
        headers: _headers())) as Map<String, dynamic>;
    return (data['processedCount'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> deleteMyData() async {
    await _decode(_client.delete(_uri('/my-data'), headers: _headers()));
  }
}
