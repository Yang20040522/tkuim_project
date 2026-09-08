import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/services/body_pose_engine.dart';
import 'package:flutter_body/services/pi_camera_source.dart';

class FakeEngine extends BodyPoseEngine {
  final List<Uint8List> calls = [];
  final first = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> processExternalFrame(Uint8List bytes, int width, int height,
      {bool isMirror = false, bool needsRotation = true}) async {
    expect(width, 8);
    expect(height, 6);
    expect(bytes.length, 8 * 6 * 3);
    expect(isMirror, isFalse);
    expect(needsRotation, isFalse);
    calls.add(bytes);
    if (calls.length == 1) {
      first.complete();
      await release.future;
    }
  }
}

Future<void> eventually(bool Function() predicate) async {
  final timeout = DateTime.now().add(const Duration(seconds: 3));
  while (!predicate()) {
    if (DateTime.now().isAfter(timeout)) fail('Condition did not become true');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Pi handshake, JPEG RGB contract, latest-frame-wins and aligned publish',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final peer = Completer<WebSocket>();
    server.listen((request) async =>
        peer.complete(await WebSocketTransformer.upgrade(request)));
    final engine = FakeEngine();
    final source =
        PiCameraSource(engine: engine, ip: '127.0.0.1', port: server.port);
    final statuses = <PiConnectionStatus>[];
    source.status.addListener(() => statuses.add(source.status.value));
    await source.start();
    expect(source.connected.value, isTrue);
    final socket = await peer.future;
    final jpeg =
        await File('test/features/tv/fixtures/frame.jpg').readAsBytes();
    // Trailing JPEG bytes identify each frame without changing decoded pixels.
    final first = Uint8List.fromList([...jpeg, 1]);
    final second = Uint8List.fromList([...jpeg, 2]);
    final third = Uint8List.fromList([...jpeg, 3]);
    socket.add(first);
    await engine.first.future;
    socket.add(second);
    socket.add(third);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(source.latestJpeg.value, isNull,
        reason: 'Never publish before inference');
    expect(engine.calls.length, 1, reason: 'Inference must not reenter');
    engine.release.complete();
    await eventually(() => source.latestJpeg.value?.last == 3);
    expect(engine.calls.length, 2,
        reason: 'Only the latest pending frame is consumed');
    expect(source.frameSize.value?.width, 8);
    expect(
        statuses,
        containsAllInOrder(
            [PiConnectionStatus.connecting, PiConnectionStatus.connected]));
    await socket.close();
    await eventually(
        () => source.status.value == PiConnectionStatus.disconnected);
    source.dispose();
    source.dispose();
    await engine.dispose();
    await server.close(force: true);
  });
  test('failed handshake is never reported as connected', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response.statusCode = 403;
      request.response.close();
    });
    final engine = FakeEngine();
    final source =
        PiCameraSource(engine: engine, ip: '127.0.0.1', port: server.port);
    final connected = <bool>[];
    source.connected.addListener(() => connected.add(source.connected.value));
    await source.start();
    expect(source.status.value, PiConnectionStatus.failed);
    expect(connected, isNot(contains(true)));
    source.dispose();
    await engine.dispose();
    await server.close(force: true);
  });
  test('dispose while inference runs never publishes to disposed notifiers',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final peer = Completer<WebSocket>();
    server.listen((request) async =>
        peer.complete(await WebSocketTransformer.upgrade(request)));
    final engine = FakeEngine();
    final source =
        PiCameraSource(engine: engine, ip: '127.0.0.1', port: server.port);
    await source.start();
    final socket = await peer.future;
    socket.add(await File('test/features/tv/fixtures/frame.jpg').readAsBytes());
    await engine.first.future;
    source.dispose();
    engine.release.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await engine.dispose();
    await socket.close();
    await server.close(force: true);
  });
}
