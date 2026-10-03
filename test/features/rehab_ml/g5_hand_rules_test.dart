import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/actions/base_rehab_action.dart';
import 'package:flutter_body/actions/rehab_action_callback.dart';
import 'package:flutter_body/actions/turn_palm_action.dart';
import 'package:flutter_body/actions/side_pinch_action.dart';
import 'package:flutter_body/actions/wrist_extension_action.dart';
import 'package:flutter_body/actions/wrist_side_bend_action.dart';
import 'package:flutter_body/controllers/rehab_session_controller.dart';
import 'package:flutter_body/models/training_action.dart';
import 'package:flutter_body/services/mediapipe_model.dart';
import 'package:flutter_body/services/mediapipe_service.dart';
import 'package:flutter_body/services/pose_model_interface.dart';

class _Callback implements RehabActionCallback {
  int reps = 0, level = 1, completions = 0;
  bool pending = false, ready = false;
  @override
  void onStatsChanged(
      {int? repCount, double? accuracy, double? progress, int? speedState}) {
    reps = repCount ?? reps;
  }

  @override
  void onFeedbackChanged(String feedback, String instruction) {}
  @override
  void onCountdownChanged(
      {required bool isCountingDown,
      required int seconds,
      required bool isDone}) {
    ready = isDone;
  }

  @override
  void onLevelUp(
      {required int newLevel,
      required String levelLabel,
      required int newTargetReps}) {
    level = newLevel;
  }

  @override
  void onLevelUpReady(
      {required int nextLevel, required String nextLevelLabel}) {
    pending = true;
  }

  @override
  void onTrainingComplete(
      {required int repCount,
      required int durationSeconds,
      required List<String> mistakeLogs}) {
    completions++;
  }
}

List<Landmark> hand({double angle = -90, double pinch = 0.8, double palm = 0}) {
  final radians = angle * math.pi / 180;
  final p = List.generate(21, (_) => const Landmark(0.5, 0.5, 0));
  p[0] = const Landmark(0.5, 0.5, 0);
  p[9] =
      Landmark(0.5 + 0.2 * math.cos(radians), 0.5 + 0.2 * math.sin(radians), 0);
  p[5] = const Landmark(0.5, 0.3, 0);
  p[17] = Landmark(0.5 + palm * 0.2, 0.4, 0);
  p[6] = const Landmark(0.5, 0.4, 0);
  p[4] = Landmark(0.5 + pinch * 0.2, 0.4, 0);
  return p;
}

void frames(BaseRehabAction action, List<Landmark> p) {
  for (var i = 0; i < 40; i++) {
    action.processLandmarks(p);
  }
}

class _Model implements IPoseModel {
  final frames = StreamController<PoseFrame>.broadcast(sync: true);
  @override
  Stream<PoseFrame> get frameStream => frames.stream;
  @override
  Stream<TrainingUpdate> get trainingStream => const Stream.empty();
  @override
  Future<void> start(PoseModelConfig config) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> flipCamera() async {}
  @override
  void dispose() {
    frames.close();
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    for (final name in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events'
    ]) {
      binding.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async {
        if (call.method == 'create') {
          final id = (call.arguments as Map)['playerId'];
          binding.defaultBinaryMessenger.setMockMethodCallHandler(
              MethodChannel('xyz.luan/audioplayers/events/$id'),
              (_) async => null);
        }
        return null;
      });
    }
  });
  test('turnPalm original stability/count/manual level upgrade unchanged',
      () async {
    final c = _Callback();
    final a = TurnPalmAction(callback: c, targetReps: 1);
    addTearDown(a.dispose);
    frames(a, hand());
    await Future<void>.delayed(const Duration(milliseconds: 8300));
    expect(c.ready, true);
    frames(a, hand(palm: 0.4));
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    frames(a, hand(palm: -0.4));
    expect(c.reps, 1);
    expect(c.pending, true);
    frames(a, hand(palm: -0.4));
    expect(c.reps, 1);
    a.confirmLevelUp(customTargetReps: 2);
    expect(c.level, 2);
    expect(c.reps, 0);
    expect(a.targetReps, 2);
  });
  test('sidePinch original open/pinch count and manual levels unchanged',
      () async {
    final c = _Callback();
    final action = SidePinchAction(callback: c, targetReps: 1);
    addTearDown(action.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 4200));
    expect(c.ready, true);
    frames(action, hand(pinch: 0.8));
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    frames(action, hand(pinch: 0.1));
    expect(c.reps, 1);
    expect(c.pending, true);
    frames(action, hand(pinch: 0.1));
    expect(c.reps, 1);
    action.confirmLevelUp(customTargetReps: 3);
    expect(c.level, 2);
    expect(c.reps, 0);
    expect(action.targetReps, 3);
  });
  for (final sideBend in [false, true]) {
    test(
        '${sideBend ? "wristSideBend" : "wristExtension"} original count/completion unchanged',
        () async {
      final c = _Callback();
      final BaseRehabAction a = sideBend
          ? WristSideBendAction(callback: c, targetReps: 1)
          : WristExtensionAction(callback: c, targetReps: 1);
      addTearDown(a.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 4200));
      expect(c.ready, true);
      frames(a, hand());
      frames(a, hand(angle: -30));
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      frames(a, hand(angle: -30));
      expect(c.reps, 0);
      frames(a, hand(angle: -150));
      if (sideBend) {
        await Future<void>.delayed(const Duration(milliseconds: 1600));
        frames(a, hand(angle: -150));
      }
      expect(c.reps, 1);
      expect(c.completions, 1);
      frames(a, hand(angle: -150));
      expect(c.reps, 1);
    });
  }
  test(
      'research callbacks cannot break controller pause/flip/count/level/dispose',
      () async {
    final model = _Model(),
        action =
            kTrainingActions.firstWhere((a) => a.type == ActionType.sidePinch);
    final controller = RehabSessionController(
        model: model,
        action: action,
        difficulty: action.difficulties.first,
        onResearchObservation: (_, __, ___, ____, _____) =>
            throw StateError('fixture'),
        onResearchReset: () => throw StateError('fixture'));
    await controller.start();
    controller.pause();
    controller.resume();
    model.frames.add(PoseFrame(handLandmarks: hand(), handDetected: true));
    controller.onStatsChanged(repCount: 2);
    expect(controller.currentState.repCount, 2);
    await controller.flipCamera();
    expect(controller.currentState.repCount, 2);
    controller.onLevelUp(newLevel: 2, levelLabel: 'fixture', newTargetReps: 3);
    expect(controller.currentState.repCount, 0);
    expect(controller.currentState.currentLevel, 2);
    await controller.disposeAsync();
  });
  test(
      'native observed landmarks are separate from predicted display/action frames',
      () async {
    for (final name in [
      'com.rehabassist/mediapipe',
      'com.rehabassist/landmarks',
      'com.rehabassist/training'
    ]) {
      binding.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
    final model = MediaPipeModel(), seen = <PoseFrame>[];
    final sub = model.frameStream.listen(seen.add);
    await model
        .start(const PoseModelConfig(actionType: 'TURN_PALM', difficulty: 1));
    Future<void> emit(double x) async {
      binding.defaultBinaryMessenger.handlePlatformMessage(
          'com.rehabassist/landmarks',
          const StandardMethodCodec().encodeSuccessEnvelope({
            'landmarks': List.generate(21, (_) => {'x': x, 'y': 0.5, 'z': 0.0}),
            'handDetected': true
          }),
          (_) {});
      await Future<void>.delayed(Duration.zero);
    }

    await emit(0.4);
    await emit(0.5);
    expect(seen.last.observedHandLandmarks!.first.x, 0.5);
    expect(seen.last.handLandmarks.first.x, closeTo(0.54, 1e-8));
    await model.stop();
    await sub.cancel();
    model.dispose();
  });
}
