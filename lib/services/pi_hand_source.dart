// lib/services/pi_hand_source.dart
//
// ══════════════════════════════════════════════════════════════════
//  樹莓派外接鏡頭 → 手部偵測來源
//  - 透過 WebSocket 連線樹莓派的 camera_server.py (ws://<pi_ip>:8765)
//  - 收到 JPEG bytes → 呼叫原生 detectHandInImage(單張圖片模式)
//  - 架構比照 pi_camera_source.dart,但吃的是手部 landmarks 而非身體骨架
// ══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'mediapipe_service.dart';

class PiHandSource {
  final String ip;
  final int port;
  final MediaPipeService service;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _processing = false;
  bool _disposed = false;

  final ValueNotifier<bool> connected = ValueNotifier(false);
  final ValueNotifier<Uint8List?> latestJpeg = ValueNotifier(null);
  final ValueNotifier<Size?> frameSize = ValueNotifier(null);
  final ValueNotifier<DetectionResult> handResult =
      ValueNotifier(DetectionResult(landmarks: [], handDetected: false));

  PiHandSource({
    required this.service,
    required this.ip,
    this.port = 8765,
  });

  Future<void> start() async {
    if (_disposed) return;

    final uri = Uri.parse('ws://$ip:$port');
    try {
      _channel = WebSocketChannel.connect(uri);
    } catch (e) {
      debugPrint('PiHandSource 連線失敗: $e');
      connected.value = false;
      return;
    }

    _sub = _channel!.stream.listen(
      _onData,
      onError: (e) {
        debugPrint('PiHandSource stream 錯誤: $e');
        connected.value = false;
      },
      onDone: () {
        debugPrint('PiHandSource 連線已關閉');
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

    _decodeSizeAndDetect(data).whenComplete(() {
      _processing = false;
    });
  }

  Future<void> _decodeSizeAndDetect(Uint8List jpegBytes) async {
    try {
      final size = await _decodeImageSize(jpegBytes);
      if (size != null) frameSize.value = size;

      final result = await service.detectHandInImage(
        jpegBytes,
        isMirror: false, // 樹莓派鏡頭固定架設,通常不需要鏡像
      );
      if (!_disposed) handResult.value = result;
    } catch (e) {
      debugPrint('PiHandSource 偵測錯誤: $e');
    }
  }

  Future<Size?> _decodeImageSize(Uint8List bytes) async {
    try {
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      return size;
    } catch (e) {
      return null;
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
    frameSize.dispose();
    handResult.dispose();
  }
}
