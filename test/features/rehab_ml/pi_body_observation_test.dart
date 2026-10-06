import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/models/body_pose_observation.dart';
import 'package:flutter_body/services/pi_camera_source.dart';

Future<void> until(bool Function() done) async {
  final clock = Stopwatch()..start();
  while (!done()) {
    if (clock.elapsedMilliseconds > 3000) fail('Timed out waiting for frame');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'same-frame packet, latest pending wins; stop/reconnect rejects stale inference',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    server.listen((request) async {
      sockets.add(await WebSocketTransformer.upgrade(request));
    });
    final started = Completer<void>(), release = Completer<void>();
    final identities = <BodyFrameIdentity>[];
    int calls = 0, active = 0, maximumActive = 0;
    final source = PiCameraSource(
        ip: '127.0.0.1',
        port: server.port,
        minimumInterval: const Duration(milliseconds: 1),
        decode: (bytes) async => PiRgbFrame(bytes, 8, 6),
        infer: (rgb, identity, current) async {
          identities.add(identity);
          calls++;
          active++;
          if (active > maximumActive) maximumActive = active;
          if (calls == 1) {
            started.complete();
            await release.future;
          }
          active--;
          return BodyPoseObservation(
              frameId: identity.frameId,
              streamSessionId: identity.streamSessionId,
              receivedAtMs: identity.receivedAtMs,
              imageWidth: rgb.width,
              imageHeight: rgb.height,
              source: 'tv_pi',
              keypoints: List.filled(17, const Offset(.5, .5)),
              scores: List.filled(17, .8));
        });
    addTearDown(() async {
      source.dispose();
      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
    });
    await source.start();
    await until(() => sockets.isNotEmpty);
    sockets.first.add(Uint8List.fromList([1]));
    await started.future;
    sockets.first.add(Uint8List.fromList([2]));
    sockets.first.add(Uint8List.fromList([3]));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(source.processedFrame.value, null);
    expect(calls, 1);
    await source.stop();
    await source.start();
    await until(() => sockets.length == 2);
    sockets.last.add(Uint8List.fromList([4]));
    release.complete();
    await until(() => source.processedFrame.value != null);
    final packet = source.processedFrame.value!;
    expect(packet.jpeg.single, 4);
    expect(packet.observation.frameId, 0);
    expect(packet.observation.streamSessionId,
        isNot(identities.first.streamSessionId));
    expect(source.latestJpeg.value, packet.jpeg);
    expect(source.frameSize.value, const Size(8, 6));
    expect(maximumActive, 1);
    expect(calls, 2);
    await source.stop();
    expect(source.processedFrame.value, null);
  });
  test('latest pending frame decoded only after active frame; no preview races',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final peer = Completer<WebSocket>();
    server.listen(
        (r) async => peer.complete(await WebSocketTransformer.upgrade(r)));
    final gate = Completer<void>();
    int calls = 0;
    final seen = <int>[];
    final source = PiCameraSource(
        ip: '127.0.0.1',
        port: server.port,
        minimumInterval: const Duration(milliseconds: 1),
        decode: (bytes) async => PiRgbFrame(bytes, 8, 6),
        infer: (rgb, identity, current) async {
          calls++;
          seen.add(rgb.rgb.first);
          if (calls == 1) await gate.future;
          return BodyPoseObservation(
              frameId: identity.frameId,
              streamSessionId: identity.streamSessionId,
              receivedAtMs: identity.receivedAtMs,
              imageWidth: 8,
              imageHeight: 6,
              source: 'tv_pi',
              keypoints: List.filled(17, const Offset(.5, .5)),
              scores: List.filled(17, .8));
        });
    await source.start();
    final socket = await peer.future;
    addTearDown(() async {
      source.dispose();
      await socket.close();
      await server.close(force: true);
    });
    socket.add([1]);
    await until(() => calls == 1);
    socket.add([2]);
    socket.add([3]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(source.latestJpeg.value, null);
    gate.complete();
    await until(() => source.latestJpeg.value?.first == 3);
    expect(seen, [1, 3]);
    expect(source.processedFrame.value!.observation.frameId, 2);
  });
  test('failed handshake never connected; dispose protects async completion',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) {
      r.response.statusCode = 403;
      r.response.close();
    });
    final source = PiCameraSource(
        ip: '127.0.0.1', port: server.port, infer: (_, __, ___) async => null);
    await source.start();
    expect(source.connected.value, false);
    expect(source.status.value, PiConnectionStatus.failed);
    source.dispose();
    source.dispose();
    await server.close(force: true);
  });
}
