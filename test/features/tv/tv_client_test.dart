import 'dart:convert';

import 'package:flutter_body/main.dart' as entry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_body/core/platform/app_platform.dart';
import 'package:flutter_body/core/ui/tv_ui.dart';
import 'package:flutter_body/features/account/login_screen.dart';
import 'package:flutter_body/features/account/role_select_screen.dart';
import 'package:flutter_body/features/account/user_role.dart';
import 'package:flutter_body/features/rehab/body_training_screen.dart';
import 'package:flutter_body/features/rehab/training_screen.dart';
import 'package:flutter_body/features/training/action_list_screen.dart';
import 'package:flutter_body/features/tv/tv_home_screen.dart';
import 'package:flutter_body/features/tv/tv_demo_viewer.dart';
import 'package:flutter_body/features/training/training_preview_screen.dart';
import 'package:flutter_body/features/plan/plan_screen.dart';
import 'package:flutter_body/actions/raise_both_arms_action.dart';
import 'package:flutter_body/models/training_action.dart';
import 'package:flutter_body/widgets/pi_ip_dialog.dart';

Widget app(Widget page) =>
    MaterialApp(theme: tvTheme(), home: TvRemoteScope(child: page));
Future<void> key(WidgetTester tester, LogicalKeyboardKey value) async {
  await tester.sendKeyEvent(value);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    AppPlatform.current = const AppCapabilities.tv();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    AppPlatform.current = const AppCapabilities.mobile();
  });
  test('TV never invokes unavailable notifications', () async {
    var called = false;
    await initializeOptionalNotifications(
        capabilities: const AppCapabilities.tv(),
        initialize: () async {
          called = true;
          throw MissingPluginException();
        });
    expect(called, isFalse);
    await initializeOptionalNotifications(
        capabilities: const AppCapabilities.mobile(),
        initialize: () async {
          throw MissingPluginException();
        });
  });
  testWidgets('actual TV entry point starts without notification plugin',
      (tester) async {
    var notificationCalls = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (call) async {
      notificationCalls++;
      throw MissingPluginException('TV notifications unavailable');
    });
    await tester.runAsync(entry.main);
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1700)));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(RoleSelectScreen), findsOneWidget);
    expect(notificationCalls, 0);
    expect(tester.takeException(), isNull);
  });

  test('TV capabilities exclude phone plugins', () {
    final tv = AppPlatform.current;
    expect(tv.supportsLocalCamera, isFalse);
    expect(tv.supportsGoogleSignIn, isFalse);
    expect(tv.supportsNotifications, isFalse);
    expect(tv.supportsTouchInput, isFalse);
    expect(tv.supportsDpad, isTrue);
    expect(tv.supportsVideoCalls, isFalse);
    expect(tv.supportsScreenRecording, isFalse);
  });
  test('IPv4 input validates complete addresses', () {
    expect(isValidPiIpv4('192.168.0.103'), isTrue);
    for (final invalid in [
      '',
      '1.2.3',
      '256.1.1.1',
      'a.1.1.1',
      '1.2.3.4:8765'
    ]) {
      expect(isValidPiIpv4(invalid), isFalse);
    }
  });
  testWidgets('D-pad login order and Select/Enter activate without pointer',
      (tester) async {
    await tester.pumpWidget(app(const LoginScreen(role: UserRole.patient)));
    await tester.pumpAndSettle();
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.first.autofocus, isTrue);
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .focusNode
            .hasFocus,
        isTrue);
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText).last)
            .focusNode
            .hasFocus,
        isTrue);
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<FilledButton>()
            ?.key,
        const Key('tv-login-submit'));
    await key(tester, LogicalKeyboardKey.select);
    expect(find.text('請輸入電子郵件或帳號 ID'), findsOneWidget);
    expect(find.text('請輸入密碼'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('login button remains visible above software keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(app(const LoginScreen(role: UserRole.patient)));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('tv-login-submit'))).bottom,
        lessThanOrEqualTo(420));
    expect(tester.takeException(), isNull);
  });
  testWidgets('role selection Enter and platform Back restore page',
      (tester) async {
    await tester.pumpWidget(app(const RoleSelectScreen()));
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.enter);
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(RoleSelectScreen), findsOneWidget);
    await key(tester, LogicalKeyboardKey.select);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
  testWidgets('body TV route renders waiting state without camera methods',
      (tester) async {
    final calls = <MethodCall>[];
    const camera = MethodChannel('plugins.flutter.io/camera_android');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(camera,
        (call) async {
      calls.add(call);
      throw PlatformException(code: 'no_cameras');
    });
    await tester
        .pumpWidget(app(BodyTrainingScreen(action: RaiseBothArmsAction())));
    await tester.pumpAndSettle();
    expect(find.text('等待外部攝影機連線'), findsOneWidget);
    expect(find.text('未連線'), findsOneWidget);
    expect(calls, isEmpty);
    await key(tester, LogicalKeyboardKey.select);
    expect(find.text('樹莓派 IP 位址'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('hand TV route never requests camera permission or platform view',
      (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (call) async {
      calls.add(call);
      throw MissingPluginException();
    });
    final action = kTrainingActions.first;
    await tester.pumpWidget(app(
        TrainingScreen(action: action, difficulty: action.difficulties.first)));
    await tester.pumpAndSettle();
    expect(find.text('等待外部攝影機連線'), findsOneWidget);
    expect(calls, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('home to selection is operable using D-pad only', (tester) async {
    await tester.pumpWidget(app(const TvHomeScreen()));
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.select);
    expect(find.byType(ActionListScreen), findsOneWidget);
    await key(tester, LogicalKeyboardKey.select);
    expect(find.text('目標次數'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'TV history groups cloud records and exposes a focusable video action',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'rehab_history': jsonEncode([
        TrainingRecord(
          id: 7,
          sessionId: 'auto:tv',
          timestamp: '2026-09-10 12:00:00',
          actionName: '翻掌訓練',
          difficulty: 1,
          durationSeconds: 5,
          mistakeLogs: const [],
          videoUrl: 'https://example.test/api/training-history/7/video',
          completedReps: 5,
          targetReps: 5,
          isSynced: true,
          isVideoSynced: true,
        ).toJson(),
      ]),
    });
    await tester.pumpWidget(app(const TvHistoryScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('翻掌訓練'), findsOneWidget);
    await tester.tap(find.textContaining('翻掌訓練'));
    await tester.pumpAndSettle();
    expect(find.text('播放訓練影片'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, '播放訓練影片'),
          )
          .autofocus,
      isTrue,
    );
  });
  testWidgets('IP dialog accepts IME done and persists IPv4', (tester) async {
    await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
                body: FilledButton(
              autofocus: true,
              onPressed: () => showPiIpDialog(context),
              child: const Text('連線'),
            )))));
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.select);
    await tester.enterText(find.byType(TextFormField), '10.0.0.8');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(await PiIpPreferences.load(), '10.0.0.8');
    await key(tester, LogicalKeyboardKey.select);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
  testWidgets(
      'TV pages fit 960x540 and 1920x1080; 3D fallback needs no WebView',
      (tester) async {
    for (final size in [const Size(960, 540), const Size(1920, 1080)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      for (final page in <Widget>[
        const TvHomeScreen(),
        const TvSettingsScreen(),
        const PlanScreen(),
        const LoginScreen(role: UserRole.patient),
        const ActionListScreen(),
        BodyTrainingScreen(action: RaiseBothArmsAction()),
        TvDemoViewer(
            demo: kActionDemo3DMap[ActionType.raiseBothArms]!,
            title: '雙手抬舉',
            description: '動作示教',
            start: () {}),
      ]) {
        await tester.pumpWidget(app(page));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '${page.runtimeType} at $size');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  testWidgets('TV numeric inputs can leave editing with D-pad Down',
      (tester) async {
    await tester.pumpWidget(app(const ActionListScreen()));
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.select);
    final field = tester.widget<EditableText>(find.byType(EditableText));
    field.focusNode.requestFocus();
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(field.focusNode.hasFocus, isFalse);
    expect(FocusManager.instance.primaryFocus, isNotNull);
  });
}
