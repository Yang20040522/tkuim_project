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

  test('forgot password sends only identifier and parses generic response',
      () async {
    final client = AuthApiClient(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(request.url.toString(), '$baseUrl/api/auth/password/forgot');
        expect(jsonDecode(request.body), {
          'identifier': 'Rehab123',
        });
        return jsonResponse(200, {
          'message': '如果帳號存在，我們已將驗證碼寄送至帳號綁定的 Email。',
        });
      }),
    );

    final result = await client.forgotPassword(identifier: 'Rehab123');
    expect(result['message'], contains('如果帳號存在'));
  });

  test('password reset sends identifier code and new password', () async {
    final client = AuthApiClient(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(request.url.toString(), '$baseUrl/api/auth/password/reset');
        expect(jsonDecode(request.body), {
          'identifier': 'patient@example.com',
          'code': '123456',
          'newPassword': 'new-password',
        });
        return jsonResponse(200, {
          'message': '密碼已更新，請使用新密碼登入',
        });
      }),
    );

    final result = await client.resetPassword(
      identifier: 'patient@example.com',
      code: '123456',
      newPassword: 'new-password',
    );
    expect(result['message'], '密碼已更新，請使用新密碼登入');
  });

  test('therapist registration never sends a client-controlled role', () async {
    final client = AuthApiClient(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(request.url.toString(), '$baseUrl/api/auth/therapist/register');
        final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        expect(body, {
          'name': '林治療師',
          'email': 'therapist@example.com',
          'password': 'password',
          'inviteCode': 'invite-code',
        });
        expect(body, isNot(contains('role')));
        return jsonResponse(200, {
          'userId': 21,
          'name': '林治療師',
          'email': 'therapist@example.com',
          'role': 'THERAPIST',
          'customExerciseToken': 'hmac-token',
        });
      }),
    );

    final result = await client.registerTherapist(
      name: '林治療師',
      email: 'therapist@example.com',
      password: 'password',
      inviteCode: 'invite-code',
    );
    expect(result['role'], 'THERAPIST');
  });
}

http.Response jsonResponse(int statusCode, Map<String, dynamic> body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}
