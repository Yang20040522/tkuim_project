import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/rehab_ml/ml_research_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() {
    AppSession.userId = '1';
    AppSession.customExerciseToken = 'synthetic-test-token';
  });
  tearDown(() {
    AppSession.userId = null;
    AppSession.customExerciseToken = null;
  });

  test('legacy consent response remains readable without availability reason',
      () {
    final consent = MlResearchConsent.fromJson({
      'active': false,
      'available': false,
      'currentVersion': 'study-v1',
    });
    expect(consent.available, isFalse);
    expect(consent.unavailableReason, isNull);
    expect(MlResearchException.unavailable(null).message, contains('尚未開放'));
  });

  for (final entry in {
    'RESEARCH_COLLECTION_NOT_ENABLED': '尚未開放',
    'RESEARCH_CONSENT_VERSION_UNSET': '版本尚未設定',
    'RESEARCH_RETENTION_UNSET': '保存政策尚未核准或尚未生效',
    'CONSENT_VERSION_MISMATCH': '同意版本已更新',
  }.entries) {
    test('maps ${entry.key} without exposing machine code', () async {
      final api = MlResearchApi(
          baseUrl: 'https://example.invalid',
          client: MockClient((_) async => http.Response(
              jsonEncode({'message': entry.key}),
              entry.key == 'CONSENT_VERSION_MISMATCH' ? 400 : 503)));
      await expectLater(
          api.setConsent(true, 'old-version'),
          throwsA(isA<MlResearchException>()
              .having(
                  (e) => e.message, 'localized message', contains(entry.value))
              .having((e) => e.code, 'safe diagnostic code', entry.key)));
    });
  }

  test(
      '401 and 403 remain distinct; arbitrary response text is never displayed',
      () async {
    for (final status in [401, 403, 500]) {
      final api = MlResearchApi(
          baseUrl: 'https://example.invalid',
          client: MockClient((_) async => http.Response(
              jsonEncode({'message': 'private-payload-do-not-display'}),
              status)));
      await expectLater(
          api.getConsent(),
          throwsA(isA<MlResearchException>()
              .having((e) => e.statusCode, 'HTTP status', status)
              .having(
                  (e) => e.message,
                  'safe message',
                  allOf(
                      isNot(contains('private-payload')),
                      contains(status == 401
                          ? '重新登入'
                          : status == 403
                              ? '權限'
                              : 'HTTP 500')))));
    }
  });

  test('proxy HTML is a safe HTTP error; network failures are distinct',
      () async {
    final proxy = MlResearchApi(
        baseUrl: 'https://example.invalid',
        client: MockClient(
            (_) async => http.Response('<html>private</html>', 502)));
    await expectLater(
        proxy.getConsent(),
        throwsA(isA<MlResearchException>()
            .having((e) => e.message, 'HTTP message', contains('HTTP 502'))));
    final offline = MlResearchApi(
        baseUrl: 'https://example.invalid',
        client: MockClient((_) async =>
            throw http.ClientException('private network details')));
    await expectLater(
        offline.getConsent(),
        throwsA(isA<MlResearchException>()
            .having((e) => e.code, 'network code', 'NETWORK_ERROR')));
  });

  test('invalid JSON is not treated as available', () async {
    final api = MlResearchApi(
        baseUrl: 'https://example.invalid',
        client: MockClient((_) async => http.Response('not-json', 200)));
    await expectLater(
        api.getConsent(),
        throwsA(isA<MlResearchException>()
            .having((e) => e.code, 'invalid response', 'INVALID_RESPONSE')));
  });
}
