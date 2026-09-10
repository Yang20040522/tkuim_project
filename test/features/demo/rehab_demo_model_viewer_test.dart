import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
// The platform interface is used only to isolate ModelViewer in widget tests.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:flutter_body/features/demo/rehab_demo_model_viewer.dart';
import 'package:flutter_body/features/training/training_preview_screen.dart';
import 'package:flutter_body/models/training_action.dart';

void main() {
  setUpAll(() {
    WebViewPlatform.instance = _FakeWebViewPlatform();
  });

  group('rehab demo camera configuration', () {
    test('every hand-focused GLB has its own measured camera', () {
      const expectedModels = {
        'assets/models/forearm_supination.glb',
        'assets/models/lateral_pinch.glb',
        'assets/models/wrist_extension.glb',
        'assets/models/turn_Right_hand.glb',
        'assets/models/turn_Left_hand.glb',
      };

      expect(kRehabDemoCameras.keys, containsAll(expectedModels));
      for (final model in expectedModels) {
        final camera = rehabDemoCameraFor(model);
        expect(camera, isNotNull, reason: model);
        expect(camera!.cameraOrbit, isNotEmpty, reason: model);
        expect(camera.cameraTarget, isNotEmpty, reason: model);
        expect(camera.fieldOfView, isNotEmpty, reason: model);
      }
    });

    test('actions without a 3D model still bypass the preview', () {
      expect(hasDemo3D(ActionType.wristSideBend), isFalse);
      expect(hasDemo3D(ActionType.bodyTest), isFalse);
    });
  });

  testWidgets('shared model viewer always disables automatic rotation',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RehabDemoModelViewer(
          src: 'assets/models/forearm_supination.glb',
          alt: '翻掌示範',
        ),
      ),
    );

    final viewer = tester.widget<ModelViewer>(find.byType(ModelViewer));
    expect(viewer.autoRotate, isFalse);
    expect(viewer.autoPlay, isTrue);
    expect(viewer.cameraOrbit, '-45deg 75deg 2.5m');
    expect(viewer.cameraTarget, '0.70m 4.70m 1.95m');
    expect(viewer.fieldOfView, '25deg');
    expect(viewer.minCameraOrbit, 'auto auto 0m');
  });

  testWidgets('left and right tabs keep the matching model and camera',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TrainingPreviewScreen(
          actionType: ActionType.reach,
          actionName: '伸手舉高訓練',
          targetScreen: _TargetScreen(),
          difficultyLabel: '測試',
          targetReps: 8,
          description: '測試說明',
        ),
      ),
    );
    await tester.pump();

    RehabDemoModelViewer currentViewer() => tester.widget<RehabDemoModelViewer>(
          find.byType(RehabDemoModelViewer),
        );

    expect(currentViewer().src, 'assets/models/turn_Right_hand.glb');
    expect(find.text('左手'), findsOneWidget);
    expect(
      rehabDemoCameraFor(currentViewer().src)?.cameraTarget,
      '0.34m 1.40m 0.30m',
    );

    await tester.tap(find.text('右手'));
    await tester.pump();

    expect(currentViewer().src, 'assets/models/turn_Left_hand.glb');
    expect(
      rehabDemoCameraFor(currentViewer().src)?.cameraTarget,
      '-0.24m 1.42m 0.32m',
    );
  });

  testWidgets('preview metadata and start-training navigation are unchanged',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TrainingPreviewScreen(
          actionType: ActionType.turnPalm,
          actionName: '翻掌訓練',
          targetScreen: _TargetScreen(),
          difficultyLabel: '測試難度',
          targetReps: 7,
          description: '原本動作說明',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('翻掌訓練'), findsOneWidget);
    expect(find.text('測試難度 · 7 下'), findsOneWidget);
    expect(find.text('原本動作說明'), findsOneWidget);

    final startButton = find.widgetWithText(ElevatedButton, '開始訓練');
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byType(_TargetScreen), findsOneWidget);
  });

  testWidgets('disposing immediately after loading does not report errors',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TrainingPreviewScreen(
          actionType: ActionType.wristExtension,
          actionName: '翹手腕式',
          targetScreen: _TargetScreen(),
          difficultyLabel: '測試',
          targetReps: 8,
          description: '測試說明',
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

class _TargetScreen extends StatelessWidget {
  const _TargetScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('訓練頁'));
}

class _FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) =>
      _FakeWebViewController(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) =>
      _FakeNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) =>
      _FakeWebViewWidget(params);
}

class _FakeWebViewController extends PlatformWebViewController {
  _FakeWebViewController(super.params) : super.implementation();

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}
}

class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {}
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  _FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
