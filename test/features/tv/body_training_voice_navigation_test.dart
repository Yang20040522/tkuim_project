import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_body/actions/raise_both_arms_action.dart';
import 'package:flutter_body/core/platform/app_platform.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/rehab/body_training_screen.dart';
import 'package:flutter_body/services/voice_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppPlatform.current = const AppCapabilities.tv();
    AppSession.userId = null;
  });
  tearDown(() {
    AppPlatform.current = const AppCapabilities.mobile();
  });

  testWidgets('TV end and completion return navigate when TTS stop never ends',
      (tester) async {
    final neverStops = Completer<void>();
    final voice = TrainingVoiceGate(
      speak: (text, {important = false}) async {},
      stop: () => neverStops.future,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BodyTrainingScreen(
                action: RaiseBothArmsAction(),
                voiceGate: voice,
              ),
            )),
            child: const Text('訓練首頁'),
          );
        }),
      ),
    ));

    await tester.tap(find.text('訓練首頁'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('暫停 / 結束'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('結束訓練'));
    await tester.pumpAndSettle();

    expect(find.text('訓練結果'), findsOneWidget);
    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    expect(find.text('訓練首頁'), findsOneWidget);
    expect(find.byType(BodyTrainingScreen), findsNothing);
  });
}
