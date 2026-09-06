import 'package:flutter/material.dart';
import 'package:flutter_body/core/ui/app_colors.dart';
import 'package:flutter_body/core/ui/app_theme.dart';
import 'package:flutter_body/features/account/account_recovery_service.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/account/auth_service.dart';
import 'package:flutter_body/features/account/forgot_password_page.dart';
import 'package:flutter_body/features/account/login_screen.dart';
import 'package:flutter_body/features/account/therapist_home_screen.dart';
import 'package:flutter_body/features/account/therapist_login_screen.dart';
import 'package:flutter_body/features/account/therapist_register_screen.dart';
import 'package:flutter_body/features/account/therapist_registration_service.dart';
import 'package:flutter_body/features/account/user_role.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSession.clear();
  });

  testWidgets('existing forgot-password entry opens the real flow once',
      (tester) async {
    await tester.pumpWidget(_app(
      const LoginScreen(role: UserRole.patient),
    ));

    expect(find.text('忘記密碼？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('forgot-password-entry')));
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordPage), findsOneWidget);
    expect(find.byKey(const Key('forgot-password-identifier')), findsOneWidget);
  });

  testWidgets('request step shows generic message and reset fields',
      (tester) async {
    final gateway = FakeRecoveryGateway();
    await tester.pumpWidget(_app(ForgotPasswordPage(gateway: gateway)));

    await tester.enterText(
      find.byKey(const Key('forgot-password-identifier')),
      'Rehab123',
    );
    await tester.tap(find.byKey(const Key('forgot-password-request-code')));
    await tester.pumpAndSettle();

    expect(gateway.requestedIdentifier, 'Rehab123');
    expect(find.byKey(const Key('recovery-generic-message')), findsOneWidget);
    expect(find.byKey(const Key('forgot-password-code')), findsOneWidget);
    expect(
        find.byKey(const Key('forgot-password-new-password')), findsOneWidget);
    expect(
      find.byKey(const Key('forgot-password-confirm-password')),
      findsOneWidget,
    );
    final resend = tester.widget<TextButton>(
      find.byKey(const Key('forgot-password-resend')),
    );
    expect(resend.onPressed, isNull);
  });

  testWidgets('password mismatch is rejected before backend reset',
      (tester) async {
    final gateway = FakeRecoveryGateway();
    await _openResetStep(tester, gateway);

    await tester.enterText(
      find.byKey(const Key('forgot-password-code')),
      '123456',
    );
    await tester.enterText(
      find.byKey(const Key('forgot-password-new-password')),
      'new-password',
    );
    await tester.enterText(
      find.byKey(const Key('forgot-password-confirm-password')),
      'different-password',
    );
    await tester.tap(find.byKey(const Key('forgot-password-submit')));
    await tester.pump();

    expect(find.text('兩次輸入的密碼不一致'), findsOneWidget);
    expect(gateway.resetCalls, 0);
  });

  testWidgets('backend reset error is shown as safe Traditional Chinese text',
      (tester) async {
    final gateway = FakeRecoveryGateway(
      resetResult: const AccountRecoveryResult.failure(
        '驗證碼無效或已過期',
        errorCode: 'INVALID_OR_EXPIRED_RESET_CODE',
      ),
    );
    await _openResetStep(tester, gateway);
    await _enterValidReset(tester);

    expect(find.byKey(const Key('forgot-password-error')), findsOneWidget);
    expect(find.text('驗證碼無效或已過期'), findsOneWidget);
  });

  testWidgets('successful reset returns to caller without retaining secrets',
      (tester) async {
    final gateway = FakeRecoveryGateway();
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => ForgotPasswordPage(gateway: gateway),
                  ),
                );
              },
              child: const Text('開啟'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('forgot-password-identifier')),
      'patient@example.com',
    );
    await tester.tap(find.byKey(const Key('forgot-password-request-code')));
    await tester.pumpAndSettle();
    await _enterValidReset(tester);

    expect(result, '密碼已更新，請使用新密碼登入');
    expect(gateway.lastCode, '123456');
    expect(gateway.lastPassword, 'new-password');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getKeys(), isEmpty);
  });

  testWidgets(
      'therapist login exposes direct registration without invite field',
      (tester) async {
    await tester.pumpWidget(_app(const TherapistLoginScreen()));

    expect(find.text('註冊治療師帳號'), findsOneWidget);
    await tester.tap(find.byKey(const Key('therapist-registration-entry')));
    await tester.pumpAndSettle();

    expect(find.byType(TherapistRegisterScreen), findsOneWidget);
    expect(find.byKey(const Key('therapist-register-name')), findsOneWidget);
    expect(find.byKey(const Key('therapist-register-email')), findsOneWidget);
    expect(
        find.byKey(const Key('therapist-register-password')), findsOneWidget);
    expect(find.byKey(const Key('therapist-invite-code')), findsNothing);
    expect(find.textContaining('角色'), findsNothing);
  });

  testWidgets('therapist password confirmation prevents submission',
      (tester) async {
    final gateway = FakeTherapistGateway();
    await tester.pumpWidget(_app(TherapistRegisterScreen(gateway: gateway)));
    await _enterTherapistForm(tester, confirmPassword: 'different-password');
    await tester
        .ensureVisible(find.byKey(const Key('therapist-register-submit')));
    await tester.tap(find.byKey(const Key('therapist-register-submit')));
    await tester.pump();

    expect(find.text('兩次輸入的密碼不一致'), findsOneWidget);
    expect(gateway.calls, 0);
  });

  testWidgets('backend therapist registration error is rendered',
      (tester) async {
    final gateway = FakeTherapistGateway(
      result: LoginResult.failure('治療師註冊資訊無效'),
    );
    await tester.pumpWidget(_app(TherapistRegisterScreen(gateway: gateway)));
    await _enterTherapistForm(tester);
    await tester
        .ensureVisible(find.byKey(const Key('therapist-register-submit')));
    await tester.tap(find.byKey(const Key('therapist-register-submit')));
    await tester.pumpAndSettle();

    expect(gateway.calls, 1);
    expect(find.text('治療師註冊資訊無效'), findsOneWidget);
  });

  testWidgets('successful therapist registration saves existing session',
      (tester) async {
    final gateway = FakeTherapistGateway(
      result: LoginResult.success(
        userId: '21',
        name: '林治療師',
        email: 'therapist@example.com',
        accountId: 'therapist21',
        bindingCode: null,
        customExerciseToken: 'hmac-token',
        backendRole: 'THERAPIST',
      ),
    );
    await tester.pumpWidget(_app(TherapistRegisterScreen(gateway: gateway)));
    await _enterTherapistForm(tester);
    await tester
        .ensureVisible(find.byKey(const Key('therapist-register-submit')));
    await tester.tap(find.byKey(const Key('therapist-register-submit')));
    await tester.pumpAndSettle();

    expect(find.byType(TherapistHomeScreen), findsOneWidget);
    expect(AppSession.role, UserRole.therapist);
    expect(AppSession.userId, '21');
    expect(AppSession.customExerciseToken, 'hmac-token');
  });

  testWidgets('therapist home displays current session name', (tester) async {
    AppSession.name = '郭宸佑';
    await tester.pumpWidget(_app(const TherapistHomeScreen()));

    final name = tester.widget<Text>(
      find.byKey(const Key('therapist-home-name')),
    );
    expect(name.data, '郭宸佑');
  });

  testWidgets('therapist home falls back when session name is missing',
      (tester) async {
    AppSession.name = '  ';
    await tester.pumpWidget(_app(const TherapistHomeScreen()));

    final name = tester.widget<Text>(
      find.byKey(const Key('therapist-home-name')),
    );
    expect(name.data, '治療師');
  });

  testWidgets('field hint stays lighter than entered active text',
      (tester) async {
    await tester.pumpWidget(_app(
      TherapistRegisterScreen(gateway: FakeTherapistGateway()),
    ));

    final decorator = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const Key('therapist-register-email')),
        matching: find.byType(InputDecorator),
      ),
    );
    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('therapist-register-email')),
        matching: find.byType(EditableText),
      ),
    );
    expect(decorator.decoration.hintStyle?.color, AppColors.hintText);
    expect(editable.style.color, AppColors.primaryText);
    expect(
      AppColors.primaryText.computeLuminance(),
      lessThan(AppColors.hintText.computeLuminance()),
    );
  });
}

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

Future<void> _openResetStep(
  WidgetTester tester,
  FakeRecoveryGateway gateway,
) async {
  await tester.pumpWidget(_app(ForgotPasswordPage(gateway: gateway)));
  await tester.enterText(
    find.byKey(const Key('forgot-password-identifier')),
    'patient@example.com',
  );
  await tester.tap(find.byKey(const Key('forgot-password-request-code')));
  await tester.pumpAndSettle();
}

Future<void> _enterValidReset(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('forgot-password-code')),
    '123456',
  );
  await tester.enterText(
    find.byKey(const Key('forgot-password-new-password')),
    'new-password',
  );
  await tester.enterText(
    find.byKey(const Key('forgot-password-confirm-password')),
    'new-password',
  );
  await tester.tap(find.byKey(const Key('forgot-password-submit')));
  await tester.pumpAndSettle();
}

Future<void> _enterTherapistForm(
  WidgetTester tester, {
  String confirmPassword = 'password',
}) async {
  await tester.enterText(
    find.byKey(const Key('therapist-register-name')),
    '林治療師',
  );
  await tester.enterText(
    find.byKey(const Key('therapist-register-email')),
    'therapist@example.com',
  );
  await tester.enterText(
    find.byKey(const Key('therapist-register-password')),
    'password',
  );
  await tester.enterText(
    find.byKey(const Key('therapist-register-confirm-password')),
    confirmPassword,
  );
}

class FakeRecoveryGateway implements AccountRecoveryGateway {
  FakeRecoveryGateway({
    this.requestResult = const AccountRecoveryResult.success(
      AccountRecoveryService.genericRequestMessage,
    ),
    this.resetResult = const AccountRecoveryResult.success(
      '密碼已更新，請使用新密碼登入',
    ),
  });

  final AccountRecoveryResult requestResult;
  final AccountRecoveryResult resetResult;
  String? requestedIdentifier;
  String? lastCode;
  String? lastPassword;
  int resetCalls = 0;

  @override
  Future<AccountRecoveryResult> requestCode(String identifier) async {
    requestedIdentifier = identifier;
    return requestResult;
  }

  @override
  Future<AccountRecoveryResult> resetPassword({
    required String identifier,
    required String code,
    required String newPassword,
  }) async {
    resetCalls++;
    lastCode = code;
    lastPassword = newPassword;
    return resetResult;
  }
}

class FakeTherapistGateway implements TherapistRegistrationGateway {
  FakeTherapistGateway({LoginResult? result})
      : result = result ?? LoginResult.failure('治療師註冊資訊無效');

  final LoginResult result;
  int calls = 0;

  @override
  Future<LoginResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    calls++;
    return result;
  }
}
