import 'package:flutter_body/services/voice_service.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> flushVoiceEvents() =>
    Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  late List<String> spoken;
  late int stops;
  late DateTime now;
  late TrainingVoiceGate gate;

  setUp(() {
    spoken = [];
    stops = 0;
    now = DateTime(2026, 9, 16);
    gate = TrainingVoiceGate(
      speak: (text, {important = false}) async {
        spoken.add(text);
      },
      stop: () async {
        stops++;
      },
      now: () => now,
    );
  });

  test('identical pose prompt is spoken once even after many frames', () async {
    for (var i = 0; i < 100; i++) {
      gate.prompt('請保持挺直');
    }
    await flushVoiceEvents();
    expect(spoken, ['請保持挺直']);
    now = now.add(const Duration(seconds: 10));
    gate.prompt('請保持挺直');
    await flushVoiceEvents();
    expect(spoken, hasLength(1));

    gate.prompt('請慢慢放下');
    await flushVoiceEvents();
    expect(spoken, ['請保持挺直', '請慢慢放下']);
  });

  test('same event is suppressed briefly but later repetitions can speak',
      () async {
    gate.event('完成一次');
    gate.event('完成一次');
    await flushVoiceEvents();
    expect(spoken, ['完成一次']);
    now = now.add(const Duration(seconds: 3));
    gate.event('完成一次');
    await flushVoiceEvents();
    expect(spoken, ['完成一次', '完成一次']);
  });

  test('hand, trained leg, mode and auto-upgrade provide spoken text',
      () async {
    gate.event(TrainingVoiceGate.selectedHand(isLeft: true), important: true);
    gate.event(TrainingVoiceGate.selectedHand(isLeft: false), important: true);
    gate.event(TrainingVoiceGate.selectedLeg(isLeft: true), important: true);
    gate.event(TrainingVoiceGate.selectedMode('簡單版', '開始抬腳'), important: true);
    gate.event(TrainingVoiceGate.autoLevel('中級'), important: true);
    await flushVoiceEvents();
    expect(spoken, [
      '已選擇左手，請將手自然放下',
      '已選擇右手，請將手自然放下',
      '已選擇左腳為訓練腳',
      '已選擇簡單版。開始抬腳',
      '已自動升級至中級，請繼續訓練',
    ]);
  });

  test('pause and dispose stop speech and reject queued events', () async {
    gate.event('舊提示');
    await gate.pause();
    gate.prompt('暫停時提示');
    await flushVoiceEvents();
    expect(spoken, isEmpty);
    expect(stops, 1);

    gate.resume();
    gate.event('繼續訓練');
    await flushVoiceEvents();
    expect(spoken, ['繼續訓練']);

    await gate.dispose();
    gate.event('離開後提示');
    await flushVoiceEvents();
    expect(stops, 2);
    expect(spoken, ['繼續訓練']);
  });

  test('finishing stops old speech and plays completion once', () async {
    gate.event('舊提示');
    await gate.finish();
    await flushVoiceEvents();
    expect(stops, 1);
    expect(spoken, ['訓練完成']);
    gate.event('完成後提示');
    await flushVoiceEvents();
    expect(spoken, ['訓練完成']);
  });
}
