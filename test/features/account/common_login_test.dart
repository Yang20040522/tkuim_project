import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/account/auth_service.dart';
import 'package:flutter_body/features/account/login_screen.dart';
import 'package:flutter_body/features/account/role_select_screen.dart';
import 'package:flutter_body/features/account/user_role.dart';
import 'package:shared_preferences/shared_preferences.dart';

LoginResult loginResult(String backendRole, {String? token = 'signed-token'}) =>
    LoginResult.success(
      userId: '42',
      name: '測試帳號',
      email: 'test@example.invalid',
      bindingCode: 'bind-code',
      friendCode: 'friend-code',
      customExerciseToken: token,
      backendRole: backendRole,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.role = null;
    AppSession.userId = null;
    AppSession.customExerciseToken = null;
  });

  testWidgets('entry has one login and separate existing registration choices',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RoleSelectScreen()));
    expect(find.text('RehabAssist 登入'), findsOneWidget);
    expect(find.text('我是病人'), findsNothing);
    expect(find.text('我是治療師'), findsNothing);
    expect(find.text('使用 Google 登入'), findsOneWidget);
    await tester.tap(find.text('還沒有帳號？註冊帳號'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('register-patient')), findsOneWidget);
    expect(find.byKey(const Key('register-therapist')), findsOneWidget);
  });

  for (final role in [UserRole.patient, UserRole.therapist]) {
    testWidgets(
        'backend ${role.name} role routes and stores only matching session',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: LoginScreen(
        login: (identifier, password) async =>
            loginResult(role.name.toUpperCase()),
        homeBuilder: (value) => Scaffold(body: Text('home-${value.name}')),
      )));
      await tester.enterText(
          find.byType(TextFormField).first, 'test@example.invalid');
      await tester.enterText(find.byType(TextFormField).last, 'secret1');
      await tester.tap(find.text('登入'));
      await tester.pumpAndSettle();
      expect(find.text('home-${role.name}'), findsOneWidget);
      expect(AppSession.role, role);
      expect(AppSession.userId, '42');
      expect(AppSession.customExerciseToken, 'signed-token');
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('unknown role or missing therapist token cannot enter or persist',
      (tester) async {
    Future<void> attempt(LoginResult result) async {
      await tester.pumpWidget(MaterialApp(
          home: LoginScreen(
        key: ValueKey(result.backendRole),
        login: (identifier, password) async => result,
        homeBuilder: (_) => const Text('should-not-enter'),
      )));
      await tester.enterText(
          find.byType(TextFormField).first, 'test@example.invalid');
      await tester.enterText(find.byType(TextFormField).last, 'secret1');
      await tester.tap(find.text('登入'));
      await tester.pumpAndSettle();
      expect(find.text('should-not-enter'), findsNothing);
      expect(AppSession.userId, isNull);
    }

    await attempt(loginResult('ADMIN'));
    await attempt(loginResult('THERAPIST', token: null));
  });
}
