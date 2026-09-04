import 'dart:convert';

import 'package:flutter_body/features/account/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const baseUrl = 'https://example.test';

  test('Google backend login parses normal login response', () async {
    final client = AuthApiClient(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(request.url.toString(), '$baseUrl/api/auth/google');
        expect(jsonDecode(request.body), {'idToken': 'id-token'});
        return jsonResponse(200, {
          'message': '登入成功',
          'userId': 12,
          'name': '王小明',
          'email': 'patient@example.com',
          'role': 'PATIENT',
          'bindingCode': 'ABC12345',
          'friendCode': 'XYZ12345',
          'customExerciseToken': 'hmac-token',
        });
      }),
    );

    final result = await client.googleLogin(idToken: 'id-token');
    expect(result['userId'], 12);
    expect(result['role'], 'PATIENT');
    expect(result['customExerciseToken'], 'hmac-token');
  });

  test('linking-required error preserves machine code internally', () async {
    final client = AuthApiClient(
      baseUrl: baseUrl,
      client: MockClient((_) async => jsonResponse(409, {
            'code': 'GOOGLE_LINK_REQUIRED',
            'message': '請驗證原帳號密碼完成綁定',
          })),
    );

    await expectLater(
      client.googleLogin(idToken: 'id-token'),
      throwsA(
        isA<AuthApiFailure>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.code, 'code', 'GOOGLE_LINK_REQUIRED')
            .having((e) => e.message, 'message', '請驗證原帳號密碼完成綁定'),
      ),
    );
  });

  test('Google link submits token and current password', () async {
    final client = AuthApiClient(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(request.url.toString(), '$baseUrl/api/auth/google/link');
        expect(jsonDecode(request.body), {
          'idToken': 'fresh-id-token',
          'currentPassword': 'original-password',
        });
        return jsonResponse(200, {
          'userId': 12,
          'name': '王小明',
          'email': 'patient@example.com',
          'role': 'PATIENT',
          'bindingCode': 'ABC12345',
          'customExerciseToken': 'hmac-token',
        });
      }),
    );

    final result = await client.linkGoogle(
      idToken: 'fresh-id-token',
      currentPassword: 'original-password',
    );
    expect(result['userId'], 12);
  });

  test('existing password login request and response remain compatible',
      () async {
    final client = AuthApiClient(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(request.url.toString(), '$baseUrl/api/auth/login');
        expect(jsonDecode(request.body), {
          'identifier': 'patient@example.com',
          'email': 'patient@example.com',
          'password': 'password',
        });
        return jsonResponse(200, {
          'userId': 7,
          'name': '既有患者',
          'email': 'patient@example.com',
          'role': 'PATIENT',
          'bindingCode': 'ABC12345',
          'customExerciseToken': 'hmac-token',
        });
      }),
    );

    final result = await client.login(
      identifier: 'patient@example.com',
      password: 'password',
    );
    expect(result['userId'], 7);
  });

  test('Account ID password login sends identifier contract', () async {
    final client = AuthApiClient(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(jsonDecode(request.body), {
          'identifier': 'Rehab123',
          'email': 'Rehab123',
          'password': 'password',
        });
        return jsonResponse(200, {
          'userId': 7,
          'name': '既有患者',
          'email': 'patient@example.com',
          'accountId': 'rehab123',
          'role': 'PATIENT',
          'customExerciseToken': 'hmac-token',
        });
      }),
    );

    final result = await client.login(
      identifier: 'Rehab123',
      password: 'password',
    );
    expect(result['accountId'], 'rehab123');
  });

  test('existing password registration success text remains compatible',
      () async {
    final client = AuthApiClient(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(request.url.toString(), '$baseUrl/api/auth/register');
        return http.Response.bytes(
          utf8.encode('註冊成功'),
          200,
          headers: {'content-type': 'text/plain; charset=utf-8'},
        );
      }),
    );

    expect(
      await client.register(
        name: '新患者',
        email: 'new@example.com',
        password: 'password',
      ),
      '註冊成功',
    );
  });
}

http.Response jsonResponse(int statusCode, Map<String, dynamic> body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}
