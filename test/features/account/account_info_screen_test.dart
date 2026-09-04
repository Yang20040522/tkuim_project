import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_body/features/account/account_api_service.dart';
import 'package:flutter_body/features/account/account_info_screen.dart';
import 'package:flutter_body/features/account/account_profile_service.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/account/google_auth_service.dart';
import 'package:flutter_body/features/account/user_role.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSession.save(
      role: UserRole.patient,
      userId: '16',
      name: '患者',
      email: 'old@example.com',
      bindingCode: 'BIND1234',
      customExerciseToken: 'signed-token',
    );
  });

  testWidgets('帳號資訊顯示 Google 狀態、Google Email 與帳號 ID', (tester) async {
    await pumpAccountScreen(
      tester,
      handler: (_) async => jsonResponse(200, accountJson()),
    );

    expect(find.text('rehab123'), findsOneWidget);
    expect(find.textContaining('已綁定'), findsOneWidget);
    expect(find.textContaining('google@gmail.com'), findsWidgets);
  });

  testWidgets('Google-only 帳號設定第一組密碼會送至 backend 並顯示成功', (tester) async {
    Map<String, dynamic>? passwordBody;
    await pumpAccountScreen(
      tester,
      handler: (request) async {
        if (request.url.path.endsWith('/password')) {
          passwordBody = Map<String, dynamic>.from(jsonDecode(request.body));
          return jsonResponse(200, accountJson(hasPassword: true));
        }
        return jsonResponse(200, accountJson(hasPassword: false));
      },
    );

    await tester.ensureVisible(find.byKey(const Key('password-status-tile')));
    await tester.tap(find.byKey(const Key('password-status-tile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('current-password-field')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('new-password-field')),
      'secret1',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-password-field')),
      'secret1',
    );
    await tester.tap(find.byKey(const Key('save-password')));
    await tester.pumpAndSettle();

    expect(passwordBody, {
      'currentPassword': null,
      'newPassword': 'secret1',
    });
    expect(find.text('密碼已設定'), findsOneWidget);
  });

  testWidgets('密碼 backend 失敗時不顯示假成功', (tester) async {
    await pumpAccountScreen(
      tester,
      handler: (request) async {
        if (request.url.path.endsWith('/password')) {
          return jsonResponse(400, {
            'code': 'INVALID_PASSWORD',
            'message': '密碼更新失敗',
          });
        }
        return jsonResponse(200, accountJson(hasPassword: false));
      },
    );

    await tester.ensureVisible(find.byKey(const Key('password-status-tile')));
    await tester.tap(find.byKey(const Key('password-status-tile')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('new-password-field')),
      'secret1',
    );
    await tester.enterText(
      find.byKey(const Key('confirm-password-field')),
      'secret1',
    );
    await tester.tap(find.byKey(const Key('save-password')));
    await tester.pumpAndSettle();

    expect(find.text('密碼更新失敗'), findsOneWidget);
    expect(find.text('密碼已設定'), findsNothing);
  });

  testWidgets('帳號 ID 前端驗證且成功更新', (tester) async {
    Map<String, dynamic>? updateBody;
    await pumpAccountScreen(
      tester,
      handler: (request) async {
        if (request.url.path.endsWith('/account-id')) {
          updateBody = Map<String, dynamic>.from(jsonDecode(request.body));
          return jsonResponse(200, accountJson(accountId: 'andrew2026'));
        }
        return jsonResponse(200, accountJson(accountId: null));
      },
    );

    await tester.tap(find.byKey(const Key('account-id-tile')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('account-id-field')), 'abc_');
    await tester.tap(find.byKey(const Key('save-account-id')));
    await tester.pump();
    expect(find.text('帳號 ID 僅能使用英文字母與數字'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('account-id-field')),
      'Andrew2026',
    );
    await tester.tap(find.byKey(const Key('save-account-id')));
    await tester.pumpAndSettle();
    expect(updateBody, {'accountId': 'Andrew2026'});
    expect(find.text('andrew2026'), findsOneWidget);
  });

  testWidgets('Google Gmail 衝突顯示安全中文訊息且不更新 session', (tester) async {
    await pumpAccountScreen(
      tester,
      credentialProvider: const _CredentialProvider('fresh-token'),
      handler: (request) async {
        if (request.url.path.endsWith('/google/link')) {
          return jsonResponse(409, {
            'code': 'GOOGLE_EMAIL_ALREADY_IN_USE',
            'message': 'raw backend message',
          });
        }
        return jsonResponse(
          200,
          accountJson(googleLinked: false, email: 'old@example.com'),
        );
      },
    );

    await tester.ensureVisible(find.byKey(const Key('google-account-status')));
    await tester.tap(find.byKey(const Key('google-account-status')));
    await tester.pumpAndSettle();

    expect(find.text('此 Google 電子郵件已綁定其他帳號，無法使用。'), findsOneWidget);
    expect(AppSession.email, 'old@example.com');
  });

  testWidgets('Google 綁定不同 Gmail 後更新 session 且保留 userId', (tester) async {
    var accountFetches = 0;
    await pumpAccountScreen(
      tester,
      credentialProvider: const _CredentialProvider('fresh-token'),
      handler: (request) async {
        if (request.url.path.endsWith('/google/link')) {
          return jsonResponse(200, loginJson(email: 'new@gmail.com'));
        }
        accountFetches++;
        return jsonResponse(
          200,
          accountJson(
            email: accountFetches == 1 ? 'old@example.com' : 'new@gmail.com',
            googleLinked: accountFetches > 1,
          ),
        );
      },
    );

    await tester.ensureVisible(find.byKey(const Key('google-account-status')));
    await tester.tap(find.byKey(const Key('google-account-status')));
    await tester.pumpAndSettle();

    expect(AppSession.userId, '16');
    expect(AppSession.email, 'new@gmail.com');
    expect(find.text('Google 帳號已綁定'), findsOneWidget);
  });

  testWidgets('取消註銷警告不會呼叫刪除', (tester) async {
    var deleted = false;
    await pumpAccountScreen(
      tester,
      handler: (request) async {
        if (request.method == 'DELETE') deleted = true;
        return jsonResponse(200, accountJson());
      },
    );

    await tester.ensureVisible(find.byKey(const Key('delete-account-button')));
    await tester.tap(find.byKey(const Key('delete-account-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('無法復原'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(deleted, isFalse);
    expect(AppSession.userId, '16');
  });

  testWidgets('正確重新驗證與最終確認後清除 session 並返回身分選擇', (tester) async {
    var deleted = false;
    await pumpAccountScreen(
      tester,
      handler: (request) async {
        if (request.method == 'DELETE') {
          deleted = true;
          expect(jsonDecode(request.body)['currentPassword'], 'secret1');
          return http.Response('', 204);
        }
        return jsonResponse(200, accountJson(hasPassword: true));
      },
    );

    await tester.ensureVisible(find.byKey(const Key('delete-account-button')));
    await tester.tap(find.byKey(const Key('delete-account-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我了解，繼續'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('delete-account-password-field')),
      'secret1',
    );
    await tester.tap(find.byKey(const Key('verify-delete-account')));
    await tester.pumpAndSettle();
    expect(find.text('最後確認'), findsOneWidget);
    await tester.tap(find.text('永久註銷'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
    expect(AppSession.userId, isNull);
    expect(AppSession.customExerciseToken, isNull);
    expect(find.text('請先選擇你的身分'), findsOneWidget);
  });

  testWidgets('重新驗證失敗不會清除 session 或離開帳號頁', (tester) async {
    await pumpAccountScreen(
      tester,
      handler: (request) async {
        if (request.method == 'DELETE') {
          return jsonResponse(400, {
            'code': 'INVALID_CREDENTIALS',
            'message': '帳號或密碼錯誤',
          });
        }
        return jsonResponse(200, accountJson(hasPassword: true));
      },
    );

    await tester.ensureVisible(find.byKey(const Key('delete-account-button')));
    await tester.tap(find.byKey(const Key('delete-account-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我了解，繼續'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('delete-account-password-field')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const Key('verify-delete-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('永久註銷'));
    await tester.pumpAndSettle();

    expect(find.text('帳號或密碼錯誤'), findsOneWidget);
    expect(AppSession.userId, '16');
    expect(AppSession.customExerciseToken, 'signed-token');
    expect(find.text('帳號資訊'), findsOneWidget);
  });
}

Future<void> pumpAccountScreen(
  WidgetTester tester, {
  required Future<http.Response> Function(http.Request request) handler,
  PatientGoogleCredentialProvider? credentialProvider,
}) async {
  tester.view.physicalSize = const Size(430, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final client = AccountApiClient(
    baseUrl: 'https://example.test',
    client: MockClient(handler),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: AccountInfoScreen(
        accountService: AccountProfileService(apiClient: client),
        googleCredentialProvider: credentialProvider,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> accountJson({
  bool googleLinked = true,
  bool hasPassword = true,
  String? accountId = 'rehab123',
  String email = 'google@gmail.com',
}) =>
    {
      'userId': 16,
      'name': '患者',
      'email': email,
      'accountId': accountId,
      'role': 'PATIENT',
      'bindingCode': 'BIND1234',
      'friendCode': 'FRND1234',
      'googleLinked': googleLinked,
      'googleEmail': googleLinked ? email : null,
      'hasPassword': hasPassword,
    };

Map<String, dynamic> loginJson({required String email}) => {
      'message': '帳號已更新',
      'userId': 16,
      'name': '患者',
      'email': email,
      'accountId': 'rehab123',
      'role': 'PATIENT',
      'bindingCode': 'BIND1234',
      'friendCode': 'FRND1234',
      'customExerciseToken': 'signed-token',
      'googleLinked': true,
    };

http.Response jsonResponse(int statusCode, Map<String, dynamic> body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

class _CredentialProvider implements PatientGoogleCredentialProvider {
  const _CredentialProvider(this.idToken);

  final String idToken;

  @override
  Future<PatientGoogleCredential> authenticate() async =>
      PatientGoogleCredential(idToken: idToken);
}
