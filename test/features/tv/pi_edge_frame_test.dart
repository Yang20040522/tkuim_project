import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/models/body_pose_observation.dart';
import 'package:flutter_body/services/pi_edge_frame.dart';
import 'package:flutter_body/services/pi_camera_source.dart';
import 'package:flutter_body/features/rehab_ml/body_research_feature_extractor.dart';

Map<String, Object?> metadata(Uint8List jpeg, {int id = 1}) => {
      'protocolVersion': 'edge-v1',
      'frameId': id,
      'monotonicTimestamp': id * 100,
      'imageWidth': 640,
      'imageHeight': 480,
      'edgeAiAvailable': true,
      'edgeModelName': 'official-test',
      'edgeModelVersion': 'test',
      'personDetected': true,
      'personConfidence': .8,
      'personBBoxPixels': {'left': 160, 'top': 80, 'right': 480, 'bottom': 400},
      'roiRecommended': {'left': 128, 'top': 48, 'right': 512, 'bottom': 432},
      'roiPaddingPolicyVersion': 'person-padding-v1',
      'jpegByteLength': jpeg.length,
      'jpegSha256': sha256.convert(jpeg).toString(),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final jpeg = Uint8List.fromList([1, 2, 3]);
  test('valid same-frame digest pair is consumed exactly once', () {
    final pair = PiEdgePairer();
    pair.receiveMetadata(jsonEncode(metadata(jpeg)), 0);
    expect(pair.pair(jpeg, 100)!.path, PiInferencePath.edgeRoi);
    expect(pair.pair(jpeg, 101), null);
  });
  for (final kind in [
    'missing',
    'malformed',
    'replaced',
    'stale',
    'duplicate',
    'out-of-order'
  ]) {
    test('$kind metadata cannot pair a wrong JPEG; usable JPEG falls back', () {
      final pair = PiEdgePairer();
      if (kind != 'missing') {
        pair.receiveMetadata(jsonEncode(metadata(jpeg)), 0);
      }
      if (kind == 'malformed') pair.receiveMetadata('{bad', 10);
      if (kind == 'replaced') {
        pair.receiveMetadata(
            jsonEncode(metadata(Uint8List.fromList([9]), id: 2)), 10);
      }
      if (kind == 'duplicate' || kind == 'out-of-order') {
        expect(pair.pair(jpeg, 1), isNotNull);
        pair.receiveMetadata(
            jsonEncode(metadata(jpeg, id: kind == 'duplicate' ? 1 : 0)), 10);
      }
      expect(pair.pair(jpeg, kind == 'stale' ? 501 : 20), null);
    });
  }
  for (final item in [
    ('edgeAiAvailable', false, PiInferencePath.edgeUnavailable),
    ('personDetected', false, PiInferencePath.noPerson),
    ('personConfidence', .2, PiInferencePath.invalidRoi),
    (
      'roiRecommended',
      {'left': 0, 'top': 0, 'right': 1, 'bottom': 1},
      PiInferencePath.invalidRoi
    ),
    ('roiPaddingPolicyVersion', 'unknown', PiInferencePath.invalidRoi),
  ]) {
    test('${item.$1} safe full-frame diagnostic', () {
      final m = metadata(jpeg)..[item.$1] = item.$2;
      expect(PiEdgeMetadata.parse(jsonEncode(m))!.path, item.$3);
    });
  }
  test('protocol, dimensions, timestamp, digest validation and reconnect reset',
      () {
    for (final change in [
      ('protocolVersion', 'v9'),
      ('imageWidth', 0),
      ('frameId', -1),
      ('jpegSha256', 'invalid'),
      ('monotonicTimestamp', -1)
    ]) {
      final m = metadata(jpeg)..[change.$1] = change.$2;
      expect(PiEdgeMetadata.parse(jsonEncode(m)), null);
    }
    final pair = PiEdgePairer();
    pair.receiveMetadata(jsonEncode(metadata(jpeg)), 0);
    expect(pair.pair(jpeg, 0), isNotNull);
    pair.reset();
    pair.receiveMetadata(jsonEncode(metadata(jpeg)), 0);
    expect(pair.pair(jpeg, 0), isNotNull);
  });
  for (final rect in [
    const Rect.fromLTRB(.2, .1, .8, .9),
    const Rect.fromLTRB(0, 0, .5, .5),
    const Rect.fromLTRB(.5, 0, 1, .5),
    const Rect.fromLTRB(0, .5, .5, 1),
    const Rect.fromLTRB(.5, .5, 1, 1)
  ]) {
    test('all-edge crop maps back to full image $rect without mirror swap', () {
      expect(remapPiRoiPoint(Offset.zero, rect), rect.topLeft);
      expect(remapPiRoiPoint(const Offset(1, 1), rect), rect.bottomRight);
      expect(remapPiRoiPoint(const Offset(.5, .5), rect), rect.center);
      expect(remapPiRoiPoint(const Offset(.2, .3), null), const Offset(.2, .3));
    });
  }
  test('pixel extraction, non-square crop, padding/clamping and invalid bounds',
      () {
    final rgb = Uint8List(640 * 480 * 3);
    const index = (48 * 640 + 128) * 3;
    rgb[index] = 23;
    final region =
        PiCropRegion.fromPixels(metadata(jpeg)['roiRecommended'], 640, 480)!;
    final crop = cropPiRgb((PiRgbFrame(rgb, 640, 480), region));
    expect(crop.rgb.first, 23);
    expect(crop.fullWidth, 640);
    expect(crop.fullHeight, 480);
    expect(crop.width, 384);
    expect(crop.height, 384);
    expect(
        remapPiRoiPoint(Offset.zero, region.normalized), const Offset(.2, .1));
    for (final bad in [double.nan, double.infinity, -1, 641]) {
      expect(
          PiCropRegion.fromPixels(
              {'left': bad, 'top': 0, 'right': 640, 'bottom': 480}, 640, 480),
          null);
    }
  });
  test('full image restoration preserves frozen R4 features and side indices',
      () {
    final raw = jsonDecode(File('test/fixtures/body_attempt_v3_synthetic.json')
        .readAsStringSync());
    const rect = Rect.fromLTRB(.1, .1, .9, .95);
    final normal = <BodyPoseObservation>[], restored = <BodyPoseObservation>[];
    for (final f in raw['frames']) {
      final points = (f['keypoints'] as List)
          .map<Offset?>((p) => p == null
              ? null
              : Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
          .toList();
      BodyPoseObservation observation(List<Offset?> p) => BodyPoseObservation(
          frameId: f['frameId'],
          streamSessionId: raw['streamSessionId'],
          receivedAtMs: f['timestampMs'],
          imageWidth: f['imageWidth'],
          imageHeight: f['imageHeight'],
          source: 'tv_pi',
          keypoints: p,
          scores: (f['scores'] as List)
              .map<double?>((s) => (s as num?)?.toDouble())
              .toList());
      normal.add(observation(points));
      restored.add(observation(points
          .map((p) => p == null
              ? null
              : remapPiRoiPoint(
                  Offset((p.dx - rect.left) / rect.width,
                      (p.dy - rect.top) / rect.height),
                  rect))
          .toList()));
    }
    for (final side in ['left', 'right']) {
      final a = BodyResearchFeatureExtractor.extract(normal, side),
          b = BodyResearchFeatureExtractor.extract(restored, side);
      expect(a.status, b.status);
      for (int i = 0; i < 5; i++) {
        if (a.values[i] != null) {
          expect(b.values[i], closeTo(a.values[i]!, 1e-10));
        }
      }
    }
    expect(restored.first.keypoints[5]!.dx,
        closeTo(normal.first.keypoints[5]!.dx, 1e-10));
    expect(restored.first.mirrored, false);
  });
  test(
      'actual WS handshake, ROI input, runtime OFF, missing metadata and dimensions fallback',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final peer = Completer<WebSocket>(), hello = Completer<String>();
    server.listen((r) async {
      final ws = await WebSocketTransformer.upgrade(r);
      ws.listen((m) => hello.complete(m as String));
      peer.complete(ws);
    });
    final inputs = <PiRgbFrame>[];
    bool failRoi = false;
    int publications = 0;
    final source = PiCameraSource(
        ip: '127.0.0.1',
        port: server.port,
        minimumInterval: Duration.zero,
        decode: (_) async => PiRgbFrame(Uint8List(640 * 480 * 3), 640, 480),
        infer: (rgb, id, current) async {
          inputs.add(rgb);
          if (failRoi && rgb.region != null) {
            throw StateError('Synthetic ROI inference failure');
          }
          final p =
              remapPiRoiPoint(const Offset(.5, .5), rgb.region?.normalized);
          return BodyPoseObservation(
              frameId: id.frameId,
              streamSessionId: id.streamSessionId,
              receivedAtMs: id.receivedAtMs,
              imageWidth: rgb.fullWidth,
              imageHeight: rgb.fullHeight,
              source: 'tv_pi',
              keypoints: List.filled(133, p),
              scores: List.filled(133, .8));
        });
    source.processedFrame.addListener(() {
      if (source.processedFrame.value != null) publications++;
    });
    await source.start();
    final ws = await peer.future;
    addTearDown(() async {
      source.dispose();
      await ws.close();
      await server.close(force: true);
    });
    expect(jsonDecode(await hello.future), {'protocol': 'edge-v1'});
    Future<void> send(Map<String, Object?>? m, int count) async {
      if (m != null) ws.add(jsonEncode(m));
      ws.add(jpeg);
      final clock = Stopwatch()..start();
      while (inputs.length < count ||
          source.processedFrame.value?.observation.frameId != count - 1) {
        if (clock.elapsedMilliseconds > 3000) fail('WS test timed out');
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    await send(metadata(jpeg), 1);
    expect(inputs.single.width, 384);
    expect(source.inferencePath.value, PiInferencePath.edgeRoi);
    expect(source.processedFrame.value!.observation.imageWidth, 640);
    expect(source.processedFrame.value!.observation.keypoints.length, 133);
    source.edgeRoiEnabled = false;
    await send(metadata(jpeg, id: 2), 2);
    expect(inputs.last.width, 640);
    expect(source.inferencePath.value, PiInferencePath.fullFrameFallback);
    source.edgeRoiEnabled = true;
    await send(null, 3);
    expect(inputs.last.width, 640);
    await send(metadata(jpeg, id: 3)..['imageWidth'] = 320, 4);
    expect(inputs.last.width, 640);
    expect(source.inferencePath.value, PiInferencePath.invalidRoi);
    failRoi = true;
    await send(metadata(jpeg, id: 4), 5);
    expect(inputs.length, 6);
    expect(inputs[4].region, isNotNull);
    expect(inputs.last.region, isNull);
    expect(source.inferencePath.value, PiInferencePath.fullFrameFallback);
    expect(publications, 5, reason: 'Retry must never publish/count twice');
  });
}
