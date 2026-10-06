import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/api_config.dart';
import 'research_owner_scope.dart';

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
    this.handAvailable = false,
  });
  final bool active;
  final bool available;
  final String currentVersion;
  final String? subjectId;
  final String? unavailableReason;
  final bool handAvailable;

  factory MlResearchConsent.fromJson(Map<String, dynamic> json) =>
      MlResearchConsent(
        active: json['active'] == true,
        available: json['available'] == true,
        handAvailable: json['handAvailable'] == true,
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
  Future<void> labelSample(String id, String label, String note,
      {String labelVersion = 'research-v1',
      String actionDefinitionVersion = 'standing-knee-raise-v1'});
  Future<Map<String, dynamic>> authority();
  Future<Map<String, dynamic>> requestReviewAccess();
  Future<List<Map<String, dynamic>>> reviewQueue();
  Future<List<Map<String, dynamic>>> reviewQueuePage(int page) =>
      page == 0 ? reviewQueue() : Future.value([]);
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
  Future<Uint8List> exportApproved({String actionId = 'standing_knee_raise'});
  Future<List<Map<String, dynamic>>> retentionPolicies();
  Future<void> createRetentionPolicy(
      {required String version,
      required int retentionDays,
      required DateTime effectiveAt,
      required String approvalReference});
  Future<int> processExpiredSamples();
  Future<void> deleteMyData();

  // Backward-compatible extension points for existing injected repositories.
  Future<void> labelSampleRevision(String id, String label, String note,
          {required String labelVersion,
          required String actionDefinitionVersion,
          required int expectedRevision}) =>
      labelSample(id, label, note,
          labelVersion: labelVersion,
          actionDefinitionVersion: actionDefinitionVersion);
  Future<Map<String, dynamic>> submitLabelRevision(String id, int revision) =>
      submitLabel(id);
  Future<Map<String, dynamic>> reviewDecision(
      String id, String decision, String note,
      {required int expectedRevision, String? reasonCode}) {
    if (decision != 'APPROVE' && decision != 'RETURN') {
      throw UnsupportedError('Review decision requires updated transport');
    }
    return reviewLabel(id, decision == 'APPROVE', note);
  }

  Future<Uint8List> exportBodyApproved({required String source}) =>
      throw UnsupportedError('Body v3 export requires updated transport');
}

/// Authenticated HTTPS transport, with explicit loopback-only validation opt-in.
/// No account identity or raw payload in logs.
class MlResearchApi implements MlResearchRemote {
  MlResearchApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl =
            (baseUrl ?? ApiConfig.baseUrl).replaceFirst(RegExp(r'/+$'), ''),
        _owner = ResearchOwnerScope.captureIfPresent();

  final http.Client _client;
  final String _baseUrl;
  ResearchOwnerScope? _owner;

  Map<String, String> _headers() {
    final scope = _owner ??= ResearchOwnerScope.capture();
    scope.check(requireToken: true);
    final id = scope.userId;
    final token = scope.token;
    if (id.isEmpty || token == null || token.isEmpty) {
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
    if (!ApiConfig.allowsResearchTransport(uri)) {
      throw const MlResearchException('研究資料同步需要安全連線。');
    }
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<dynamic> _decode(Future<http.Response> request) async {
    final http.Response response;
    try {
      response = await request.timeout(const Duration(seconds: 20));
      _owner?.check(requireToken: true);
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
  Future<void> labelSample(String id, String label, String note,
      {String labelVersion = 'research-v1',
      String actionDefinitionVersion = 'standing-knee-raise-v1'}) async {
    await _decode(_client.put(
      _uri('/samples/${Uri.encodeComponent(id)}/label'),
      headers: _headers(),
      body: jsonEncode({
        'label': label,
        'note': note,
        'labelVersion': labelVersion,
        'actionDefinitionVersion': actionDefinitionVersion,
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
    return reviewQueuePage(0);
  }

  @override
  Future<List<Map<String, dynamic>>> reviewQueuePage(int page) async {
    final data = await _decode(_client.get(
        _uri('/review-queue', {'page': '$page', 'size': '20'}),
        headers: _headers())) as Map<String, dynamic>;
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
  Future<Uint8List> exportApproved(
      {String actionId = 'standing_knee_raise'}) async {
    final response = await _client
        .get(
            _uri('/management/export')
                .replace(queryParameters: {'actionId': actionId}),
            headers: _headers())
        .timeout(const Duration(seconds: 30));
    _owner?.check(requireToken: true);
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

  @override
  Future<void> labelSampleRevision(String id, String label, String note,
      {required String labelVersion,
      required String actionDefinitionVersion,
      required int expectedRevision}) async {
    await _decode(_client.put(_uri('/samples/${Uri.encodeComponent(id)}/label'),
        headers: _headers(),
        body: jsonEncode({
          'label': label,
          'note': note,
          'labelVersion': labelVersion,
          'actionDefinitionVersion': actionDefinitionVersion,
          'expectedRevision': expectedRevision,
        })));
  }

  @override
  Future<Map<String, dynamic>> submitLabelRevision(
          String id, int revision) async =>
      await _decode(_client.post(
              _uri('/samples/${Uri.encodeComponent(id)}/label/submit'),
              headers: _headers(),
              body: jsonEncode({'expectedRevision': revision})))
          as Map<String, dynamic>;

  @override
  Future<Map<String, dynamic>> reviewDecision(
          String id, String decision, String note,
          {required int expectedRevision, String? reasonCode}) async =>
      await _decode(
          _client.post(_uri('/samples/${Uri.encodeComponent(id)}/label/review'),
              headers: _headers(),
              body: jsonEncode({
                'decision': decision,
                'note': note,
                'expectedRevision': expectedRevision,
                'reasonCode': reasonCode,
              }))) as Map<String, dynamic>;

  @override
  Future<Uint8List> exportBodyApproved({required String source}) async {
    final response = await _client
        .get(
            _uri('/management/export', {
              'actionId': 'standing_knee_raise',
              'schemaVersion': '3',
              'source': source,
            }),
            headers: _headers())
        .timeout(const Duration(seconds: 30));
    _owner?.check(requireToken: true);
    if (response.statusCode != 200 ||
        response.headers['content-type']?.contains('application/zip') != true) {
      throw MlResearchException.fromResponse(response.statusCode);
    }
    return response.bodyBytes;
  }
}
