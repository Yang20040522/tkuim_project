import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/actions/body_rehab_action.dart';
import 'package:flutter_body/actions/reach_action.dart';
import 'package:flutter_body/features/rehab/body_training_screen.dart';
import 'package:flutter_body/features/rehab/training_camera_session.dart';
import 'package:flutter_body/features/rehab/training_screen.dart';
import 'package:flutter_body/models/training_action.dart';

void main() {
  final handAction = kTrainingActions.firstWhere(
    (action) => action.type == ActionType.turnPalm,
  );
  final bodyAction = kTrainingActions.firstWhere(
    (action) => action.type == ActionType.reach,
  );

  group('training camera selection', () {
    test('phone retry selection remains phone', () {
      const selection = TrainingCameraSelection.phone();

      expect(selection.source, TrainingCameraSource.phone);
      expect(selection.raspberryPiIp, isNull);
      expect(selection.isValid, isTrue);
    });

    test('Raspberry Pi retry selection retains the successful IP', () {
      const selection = TrainingCameraSelection.raspberryPi('192.168.1.42');

      expect(selection.source, TrainingCameraSource.raspberryPi);
      expect(selection.raspberryPiIp, '192.168.1.42');
      expect(selection.isValid, isTrue);
    });

    test('rapid retry taps start the camera pipeline only once', () async {
      final guard = TrainingRestartGuard();
      final release = Completer<void>();
      var pipelineStarts = 0;

      final first = guard.run(() async {
        pipelineStarts++;
        await release.future;
      });
      final second = await guard.run(() async {
        pipelineStarts++;
      });

      expect(second, isFalse);
      expect(pipelineStarts, 1);
      release.complete();
      expect(await first, isTrue);
    });

    test('hand and body retry routes accept the retained Pi selection', () {
      const selection = TrainingCameraSelection.raspberryPi('10.0.0.8');
      final difficulty = handAction.difficulties.first.copyWithReps(12);
      final bodyDifficulty = bodyAction.difficulties.first.copyWithReps(12);

      final handScreen = TrainingScreen(
        action: handAction,
        difficulty: difficulty,
        initialCameraSelection: selection,
      );
      final bodyScreen = BodyTrainingScreen(
        action: ReachAction(
          difficulty: RehabDifficulty.easy,
          targetCount: 12,
        ),
        trainingActionMeta: bodyAction,
        difficultyMeta: bodyDifficulty,
        initialCameraSelection: selection,
      );

      expect(handScreen.initialCameraSelection.raspberryPiIp, '10.0.0.8');
      expect(bodyScreen.initialCameraSelection.raspberryPiIp, '10.0.0.8');
      expect(bodyScreen.difficultyMeta?.targetReps, 12);
    });

    testWidgets('connection failure is explicit and remains retryable',
        (tester) async {
      var retryCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CameraConnectionErrorOverlay(
            message: '無法重新連接樹莓派鏡頭（10.0.0.8）。',
            onRetry: () => retryCount++,
          ),
        ),
      );

      expect(find.textContaining('無法重新連接樹莓派鏡頭'), findsOneWidget);
      expect(find.text('重新連線'), findsOneWidget);
      await tester.tap(find.text('重新連線'));
      expect(retryCount, 1);
    });
  });

  group('body repetition progress', () {
    test('uses the current 12-rep target from zero through completion', () {
      expect(formatRepProgress(0, 12), '0/12');
      expect(formatRepProgress(1, 12), '1/12');
      expect(formatRepProgress(12, 12), '12/12');
    });

    test('uses a custom 8-rep target instead of a hard-coded denominator', () {
      expect(formatRepProgress(0, 8), '0/8');
    });

    test('copying a plan target keeps completion and display in sync', () {
      final planDifficulty = bodyAction.difficulties.first.copyWithReps(12);

      expect(planDifficulty.targetReps, 12);
      expect(formatRepProgress(0, planDifficulty.targetReps), '0/12');
    });
  });
}
