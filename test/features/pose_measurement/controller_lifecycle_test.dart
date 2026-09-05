import 'dart:async';

import 'package:flutter_body/features/pose_measurement/pose_camera_controller.dart';
import 'package:flutter_body/features/pose_measurement/pose_detector_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('permission denied never starts camera and retry can grant', () async {
    final platform = _Platform();
    var permission = PoseCameraPermission.denied;
    final controller = PoseCameraController(
      platformFactory: (_) => platform,
      requestPermission: () async => permission,
    );
    controller.attach(1);
    controller.setActive(true);
    await settle();
    expect(controller.state.value, PoseCameraState.permissionDenied);
    expect(platform.starts, 0);
    permission = PoseCameraPermission.granted;
    controller.retry();
    await settle();
    expect(platform.starts, 1);
    controller.dispose();
    await settle();
    expect(platform.stops, greaterThan(0));
    await platform.close();
  });

  test('permanently denied has its own configuration state', () async {
    final platform = _Platform();
    final controller = PoseCameraController(
      platformFactory: (_) => platform,
      requestPermission: () async => PoseCameraPermission.permanentlyDenied,
    );
    controller.attach(1);
    controller.setActive(true);
    await settle();
    expect(controller.state.value, PoseCameraState.permissionPermanentlyDenied);
    expect(platform.starts, 0);
    controller.dispose();
    await platform.close();
  });

  test('background during permission cannot start; resume starts once',
      () async {
    final platform = _Platform();
    final permission = Completer<PoseCameraPermission>();
    var requests = 0;
    final controller = PoseCameraController(
      platformFactory: (_) => platform,
      requestPermission: () {
        requests++;
        return permission.future;
      },
    );
    controller.attach(1);
    controller.setActive(true);
    controller.setActive(false);
    controller.setActive(true);
    permission.complete(PoseCameraPermission.granted);
    await settle();
    expect(requests, 1);
    expect(platform.starts, 1);
    controller.setActive(false);
    await settle();
    expect(controller.state.value, PoseCameraState.paused);
    final stops = platform.stops;
    controller.setActive(false);
    await settle();
    expect(platform.stops, stops);
    controller.dispose();
    await platform.close();
  });

  test('dispose before permission resolution suppresses late start', () async {
    final platform = _Platform();
    final permission = Completer<PoseCameraPermission>();
    final controller = PoseCameraController(
      platformFactory: (_) => platform,
      requestPermission: () => permission.future,
    );
    controller.attach(1);
    controller.setActive(true);
    controller.dispose();
    permission.complete(PoseCameraPermission.granted);
    await settle();
    expect(platform.starts, 0);
    expect(platform.stops, 1);
    await platform.close();
  });

  test('pending start is followed by stop before resumed start', () async {
    final platform = _Platform()..pendingStart = Completer<void>();
    final controller = PoseCameraController(
      platformFactory: (_) => platform,
      requestPermission: () async => PoseCameraPermission.granted,
    );
    controller.attach(1);
    controller.setActive(true);
    await settle();
    controller.setActive(false);
    controller.setActive(true);
    await settle();
    expect(platform.calls, ['start']);
    platform.pendingStart!.complete();
    await settle();
    expect(platform.calls, ['start', 'stop', 'start']);
    controller.dispose();
    await settle();
    expect(platform.calls.last, 'stop');
    await platform.close();
  });

  test('states distinguish no pose from low confidence partial landmarks',
      () async {
    final platform = _Platform();
    final controller = PoseCameraController(
      platformFactory: (_) => platform,
      requestPermission: () async => PoseCameraPermission.granted,
    );
    controller.attach(1);
    controller.setActive(true);
    await settle();
    platform.emit({'type': 'state', 'state': 'loadingModel'});
    expect(controller.state.value, PoseCameraState.loadingModel);
    platform.emit(_frame([]));
    expect(controller.state.value, PoseCameraState.noPose);
    platform.emit(_frame(List.generate(
      33,
      (_) => {'x': .5, 'y': .5, 'z': 0.0, 'visibility': .1, 'presence': .1},
    )));
    expect(controller.state.value, PoseCameraState.detected);
    expect(controller.frame.value!.hasPose, isTrue);
    controller.setActive(false);
    platform.emit(_frame([]));
    expect(controller.state.value, PoseCameraState.paused);
    expect(controller.frame.value, isNull);
    controller.dispose();
    platform.emit({'type': 'state', 'state': 'ready'});
    await platform.close();
  });

  test('new view releases old pipeline and starts only the new one', () async {
    final first = _Platform();
    final second = _Platform();
    final controller = PoseCameraController(
      platformFactory: (id) => id == 1 ? first : second,
      requestPermission: () async => PoseCameraPermission.granted,
    );
    controller.attach(1);
    controller.setActive(true);
    await settle();
    controller.attach(2);
    await settle();
    expect(first.starts, 1);
    expect(first.stops, 1);
    expect(second.starts, 1);
    first.emit({'type': 'state', 'state': 'error'});
    expect(controller.state.value, PoseCameraState.initializing);
    controller.dispose();
    await settle();
    expect(second.stops, 1);
    await first.close();
    await second.close();
  });

  test('native errors clear pose and stop without exposing raw messages',
      () async {
    final platform = _Platform();
    final controller = PoseCameraController(
      platformFactory: (_) => platform,
      requestPermission: () async => PoseCameraPermission.granted,
    );
    controller.attach(1);
    controller.setActive(true);
    await settle();
    platform.emit({'type': 'state', 'state': 'error', 'message': 'raw detail'});
    await settle();
    expect(controller.state.value, PoseCameraState.error);
    expect(controller.state.value.label, isNot(contains('raw detail')));
    expect(controller.frame.value, isNull);
    expect(platform.stops, 1);
    controller.dispose();
    await platform.close();
  });

  test('unexpected stream closure stops instead of retaining stale pose',
      () async {
    final platform = _Platform();
    final controller = PoseCameraController(
      platformFactory: (_) => platform,
      requestPermission: () async => PoseCameraPermission.granted,
    );
    controller.attach(1);
    controller.setActive(true);
    await settle();
    await platform.close();
    await settle();
    expect(controller.state.value, PoseCameraState.error);
    expect(controller.frame.value, isNull);
    expect(platform.stops, 1);
    controller.dispose();
  });
}

Map<String, dynamic> _frame(List<Map<String, double>> landmarks) => {
      'type': 'frame',
      'timestampMs': 100,
      'landmarks': landmarks,
      'worldLandmarks': const [],
      'inferenceMs': 15.0,
    };

class _Platform implements PoseDetectorPlatform {
  final _events = StreamController<Map<dynamic, dynamic>>.broadcast(sync: true);
  final calls = <String>[];
  Completer<void>? pendingStart;
  int get starts => calls.where((call) => call == 'start').length;
  int get stops => calls.where((call) => call == 'stop').length;

  void emit(Map<dynamic, dynamic> event) => _events.add(event);
  Future<void> close() => _events.close();

  @override
  Stream<Map<dynamic, dynamic>> get events => _events.stream;

  @override
  Future<void> start() async {
    calls.add('start');
    await pendingStart?.future;
  }

  @override
  Future<void> stop() async => calls.add('stop');
}
