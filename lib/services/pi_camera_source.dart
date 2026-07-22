// lib/services/pi_camera_source.dart
//
// ══════════════════════════════════════════════════════════════════
//  樹莓派外接鏡頭來源
//  - 透過 WebSocket 連線樹莓派的 camera_server.py (ws://<pi_ip>:8765)
//  - 收到 JPEG bytes → 解碼成 RGB → 餵進 BodyPoseEngine.processExternalFrame
// ══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'body_pose_engine.dart';

class PiCameraSource {
  final String ip;
  final int port;
  final BodyPoseEngine engine;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _processing = false;
  bool _disposed = false;

  final ValueNotifier<bool> connected = ValueNotifier(false);
  final ValueNotifier<Uint8List?> latestJpeg = ValueNotifier(null);

  PiCameraSource({
    required this.engine,
    required this.ip,
    this.port = 8765,
  });

  Future<void> start() async {
    if (_disposed) return;

    final uri = Uri.parse('ws://$ip:$port');
    try {
      _channel = WebSocketChannel.connect(uri);
    } catch (e) {
      debugPrint('PiCameraSource 連線失敗: $e');
      connected.value = false;
      return;
    }

    _sub = _channel!.stream.listen(
      _onData,
      onError: (e) {
        debugPrint('PiCameraSource stream 錯誤: $e');
        connected.value = false;
      },
      onDone: () {
        debugPrint('PiCameraSource 連線已關閉');
        connected.value = false;
      },
      cancelOnError: false,
    );

    connected.value = true;
  }

  void _onData(dynamic data) {
    if (_disposed) return;
    if (data is! Uint8List) return;

    latestJpeg.value = data;

    if (_processing) return;
    _processing = true;

    _decodeAndInfer(data).whenComplete(() {
      _processing = false;
    });
  }

  Future<void> _decodeAndInfer(Uint8List jpegBytes) async {
    try {
      final decoded = img.decodeJpg(jpegBytes);
      if (decoded == null) return;

      final rgbImage = decoded.convert(numChannels: 3);
      final rgbBytes = rgbImage.toUint8List();

      await engine.processExternalFrame(
        rgbBytes,
        rgbImage.width,
        rgbImage.height,
        isMirror: false,
        needsRotation: false, // 樹莓派畫面本身是正的,不能套用手機鏡頭的 90 度校正映射
      );
    } catch (e) {
      debugPrint('PiCameraSource 解碼/推論錯誤: $e');
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    await _channel?.sink.close();
    _sub = null;
    _channel = null;
    connected.value = false;
  }

  void dispose() {
    _disposed = true;
    stop();
    connected.dispose();
    latestJpeg.dispose();
  }
}