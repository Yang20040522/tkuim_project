import 'dart:convert';

import 'package:flutter_body/features/account/account_api_service.dart';
import 'package:flutter_body/features/account/api_service.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/account/user_role.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const baseUrl = 'https://example.test';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSession.save(
      role: UserRole.patient,
      userId: '16',
      email: 'old@example.com',
      customExerciseToken: 'signed-token',
    );
  });

  test('account info uses HMAC headers and parses safe identity state',
      () async {
    final client = AccountApiClient(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(request.url.path, '/api/account/me');
        expect(request.headers['X-User-Id'], '16');
        expect(request.headers['X-Custom-Exercise-Token'], 'signed-token');
        return jsonResponse(200, accountJson());
      }),
    );

    final account = await client.getAccountInfo();

    expect(account.accountId, 'rehab123');
    expect(account.googleLinked, isTrue);
    expect(account.googleEmail, 'google@gmail.com');
    expect(account.hasPassword, isTrue);
  });

  test('first password request is sent to authenticated backend only',
      () async {
    final client = AccountApiClient(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/account/password');
        expect(jsonDecode(request.body), {
          'currentPassword': null,
          'newPassword': 'secret1',
        });
        return jsonResponse(200, accountJson(hasPassword: true));
      }),
    );

    final account = await client.updatePassword(newPassword: 'secret1');
    expect(account.hasPassword, isTrue);
  });

  test('authenticated Google bind parses normal login session response',
      () async {
    final client = AccountApiClient(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(request.url.path, '/api/account/google/link');
        expect(jsonDecode(request.body), {'idToken': 'fresh-token'});
        return jsonResponse(200, {
          'userId': 16,
          'name': '患者',
          'email': 'new@gmail.com',
          'accountId': 'rehab123',
          'role': 'PATIENT',
          'bindingCode': 'BIND1234',
          'customExerciseToken': 'signed-token',
          'googleLinked': true,
        });
      }),
    );

    final result = await client.linkGoogle('fresh-token');
    expect(result.success, isTrue);
    expect(result.userId, '16');
    expect(result.email, 'new@gmail.com');
    expect(result.accountId, 'rehab123');
  });

  test('Gmail conflict preserves machine-readable code', () async {
    final client = AccountApiClient(
      baseUrl: baseUrl,
      client: MockClient((_) async => jsonResponse(409, {
            'code': 'GOOGLE_EMAIL_ALREADY_IN_USE',
            'message': '此 Google 電子郵件已綁定其他帳號，無法使用。',
          })),
    );

    await expectLater(
      client.linkGoogle('fresh-token'),
      throwsA(
        isA<AuthApiFailure>().having(
          (error) => error.code,
          'code',
          'GOOGLE_EMAIL_ALREADY_IN_USE',
        ),
      ),
    );
  });

  test('delete sends fresh password proof with authenticated identity',
      () async {
    final client = AccountApiClient(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/account/me');
        expect(jsonDecode(request.body), {
          'currentPassword': 'secret1',
          'idToken': null,
        });
        return http.Response('', 204);
      }),
    );

    await client.deleteAccount(currentPassword: 'secret1');
  });

  test('missing AppSession HMAC fails locally without network call', () async {
    await AppSession.clear();
    var called = false;
    final client = AccountApiClient(
      baseUrl: baseUrl,
      client: MockClient((_) async {
        called = true;
        return http.Response('', 500);
      }),
    );

    await expectLater(
      client.getAccountInfo(),
      throwsA(isA<AuthApiFailure>()),
    );
    expect(called, isFalse);
  });
}

Map<String, dynamic> accountJson({bool hasPassword = true}) => {
      'userId': 16,
      'name': '患者',
      'email': 'google@gmail.com',
      'accountId': 'rehab123',
      'role': 'PATIENT',
      'bindingCode': 'BIND1234',
      'friendCode': 'FRND1234',
      'googleLinked': true,
      'googleEmail': 'google@gmail.com',
      'hasPassword': hasPassword,
    };

http.Response jsonResponse(int statusCode, Map<String, dynamic> body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}
