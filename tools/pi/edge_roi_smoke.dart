// Engineering-only entry point. No auth, backend, collector, patient records or
// persisted images. Normal lib/main.dart never imports this file.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_body/models/body_pose_observation.dart';
import 'package:flutter_body/services/body_pose_engine.dart';
import 'package:flutter_body/services/pi_camera_source.dart';
import 'package:flutter_body/services/pi_edge_frame.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: _Smoke()));
}

class _Smoke extends StatefulWidget {
  const _Smoke();
  @override
  State<_Smoke> createState() => _SmokeState();
}

class _SmokeState extends State<_Smoke> {
  final engine = BodyPoseEngine();
  PiCameraSource? source;
  String status = 'Round 7 engineering validation — no research collection';
  final times = <Map<String, int>>[];

  Map<String, Object> summary(List<Map<String, int>> frames) {
    return {
      'frames': frames.length,
      for (final field in frames.first.keys)
        field: (() {
          final v = frames.map((f) => f[field]!).toList()..sort();
          return {
            'p50': v[v.length ~/ 2],
            'p95': v[((v.length - 1) * .95).ceil()]
          };
        })(),
    };
  }

  Future<void> replay(Uint8List rgb) async {
    final jpeg = Uint8List.fromList(img.encodeJpg(
        img.Image.fromBytes(
            width: 640, height: 480, bytes: rgb.buffer, numChannels: 3),
        quality: 60));
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final peer = Completer<WebSocket>();
    server.listen((r) async {
      final socket = await WebSocketTransformer.upgrade(r);
      socket.listen((_) {}); // Client's edge-v1 opt-in.
      peer.complete(socket);
    });
    final source =
        PiCameraSource(engine: engine, ip: '127.0.0.1', port: server.port);
    final full = <Map<String, int>>[], roi = <Map<String, int>>[];
    WebSocket? socket;
    try {
      await source.start();
      socket = await peer.future;
      for (int i = 0; i < 20; i++) {
        source.edgeRoiEnabled = i >= 10;
        await Future<void>.delayed(const Duration(milliseconds: 40));
        final done = Completer<void>();
        void received() {
          if (source.processedFrame.value?.observation.frameId == i &&
              !done.isCompleted) {
            done.complete();
          }
        }

        source.processedFrame.addListener(received);
        try {
          socket.add(jsonEncode({
            'protocolVersion': 'edge-v1',
            'frameId': i + 1,
            'monotonicTimestamp': (i + 1) * 100,
            'imageWidth': 640,
            'imageHeight': 480,
            'edgeAiAvailable': true,
            'edgeModelName': 'SYNTHETIC_PROTOCOL_FIXTURE',
            'edgeModelVersion': 'engineering-only',
            'personDetected': true,
            'personConfidence': .8,
            'personBBoxPixels': {
              'left': 160,
              'top': 80,
              'right': 480,
              'bottom': 400
            },
            'roiRecommended': {
              'left': 128,
              'top': 48,
              'right': 512,
              'bottom': 432
            },
            'roiPaddingPolicyVersion': 'person-padding-v1',
            'jpegByteLength': jpeg.length,
            'jpegSha256': sha256.convert(jpeg).toString(),
          }));
          socket.add(jpeg);
          await done.future.timeout(const Duration(seconds: 10));
          final expected = i >= 10
              ? PiInferencePath.edgeRoi
              : PiInferencePath.fullFrameFallback;
          if (source.inferencePath.value != expected ||
              source.processedFrame.value!.observation.keypoints.length !=
                  133 ||
              source.processedFrame.value!.observation.imageWidth != 640) {
            throw StateError('Synthetic replay path/geometry failure');
          }
          (i >= 10 ? roi : full).add(Map.of(source.lastTimingsUs));
        } finally {
          source.processedFrame.removeListener(received);
        }
      }
      debugPrint('R7_SYNTHETIC_REPLAY_FULL PASS ${jsonEncode(summary(full))}');
      debugPrint('R7_SYNTHETIC_REPLAY_ROI PASS ${jsonEncode(summary(roi))}');
    } finally {
      await source.stop();
      source.dispose();
      await socket?.close();
      await server.close(force: true);
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(validate());
  }

  Future<void> validate() async {
    try {
      await engine.initForExternalFrames();
      final rgb = Uint8List(640 * 480 * 3);
      // Deterministic synthetic gradient, not a person/photo/training sample.
      for (int y = 0; y < 480; y++) {
        for (int x = 0; x < 640; x++) {
          final i = (y * 640 + x) * 3;
          rgb[i] = x % 256;
          rgb[i + 1] = y % 256;
          rgb[i + 2] = 128;
        }
      }
      const roi = PiCropRegion(128, 48, 512, 432, 640, 480);
      final crop = cropPiRgb((PiRgbFrame(rgb, 640, 480), roi));
      for (int i = 0; i < 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        final useRoi = i.isOdd;
        final result = await engine.processExternalFrame(
          useRoi ? crop.rgb : rgb,
          useRoi ? crop.width : 640,
          useRoi ? crop.height : 480,
          needsRotation: false,
          sourceRegion: useRoi ? roi.normalized : null,
          fullImageWidth: 640,
          fullImageHeight: 480,
          identity: BodyFrameIdentity(
              frameId: i,
              streamSessionId: 'synthetic-${useRoi ? "roi" : "full"}',
              receivedAtMs: i * 100),
        );
        if (result == null ||
            result.keypoints.length != 133 ||
            result.imageWidth != 640 ||
            result.imageHeight != 480 ||
            result.mirrored) {
          throw StateError(
              'Synthetic ONNX/full-image metadata validation failed');
        }
        if (useRoi &&
            result.keypoints
                .whereType<Offset>()
                .any((p) => p.dx < .2 || p.dx > .8 || p.dy < .1 || p.dy > .9)) {
          throw StateError('ROI output was not remapped before publication');
        }
        debugPrint('R7_SYNTHETIC_ONNX ${useRoi ? "ROI" : "FULL"} PASS '
            '${jsonEncode(engine.lastInferenceTimingsUs)}');
      }
      await replay(rgb);
      source = PiCameraSource(
          engine: engine,
          ip: const String.fromEnvironment('PI_EDGE_SMOKE_HOST',
              defaultValue: '192.168.137.186'));
      final complete = Completer<void>();
      int frames = 0;
      source!.processedFrame.addListener(() {
        final packet = source!.processedFrame.value;
        if (packet == null || complete.isCompleted) return;
        if (packet.observation.keypoints.length != 133 ||
            packet.observation.imageWidth != 640 ||
            packet.observation.imageHeight != 480) {
          complete
              .completeError(StateError('Live full-frame geometry mismatch'));
          return;
        }
        frames++;
        times.add(Map.of(source!.lastTimingsUs));
        if (mounted) {
          setState(() => status =
              'LIVE Pi frame $frames / 20 — ${source!.inferencePath.value.diagnostic}');
        }
        if (frames == 20) complete.complete();
      });
      await source!.start();
      await complete.future.timeout(const Duration(seconds: 50));
      debugPrint(
          'R7_LIVE_PI_RTMPOSE PASS frames=$frames path=${source!.inferencePath.value.diagnostic} timingSummaryUs=${jsonEncode(summary(times))}');
      // Verify runtime OFF + reconnect without camera/model duplication.
      await source!.stop();
      source!.edgeRoiEnabled = false;
      await source!.start();
      await source!.waitForFirstFrame(timeout: const Duration(seconds: 20));
      if (source!.inferencePath.value != PiInferencePath.fullFrameFallback) {
        throw StateError('Runtime OFF did not use original full frame');
      }
      debugPrint('R7_RUNTIME_OFF_RECONNECT PASS');
      await source!.stop();
      if (mounted) {
        setState(() => status =
            'PASS: synthetic ROI ONNX + live Pi + OFF/reconnect\nNo research samples or clinical claims.');
      }
    } catch (error) {
      debugPrint('R7_SMOKE FAIL ${error.runtimeType}: $error');
      if (mounted) {
        setState(() =>
            status = 'Engineering validation failed: ${error.runtimeType}');
      }
    } finally {
      await source?.stop();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: Text(status,
                style: const TextStyle(color: Colors.white, fontSize: 24))),
      );
  @override
  void dispose() {
    source?.dispose();
    unawaited(engine.dispose());
    super.dispose();
  }
}
