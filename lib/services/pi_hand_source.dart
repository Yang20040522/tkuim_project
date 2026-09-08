// lib/services/pi_hand_source.dart
//
// ══════════════════════════════════════════════════════════════════
//  樹莓派外接鏡頭 → 手部偵測來源
//  - 透過 WebSocket 連線樹莓派的 camera_server.py (ws://<pi_ip>:8765)
//  - 收到 JPEG bytes → 呼叫原生 detectHandInImage(單張圖片模式)
//  - 架構比照 pi_camera_source.dart,但吃的是手部 landmarks 而非身體骨架
//
//  🚀 修正:畫面顯示與手部偵測結果必須「鎖同一幀」,否則手部骨架
//     會對不上畫面。原本邏輯是「新幀一到就立刻顯示,但偵測忙碌時
//     就丟棄該幀」,導致顯示的畫面已經跑到後面幾幀,手部座標卻還是
//     舊幀算出來的位置,動作快的時候特別明顯。
//     改成:先完成偵測,再把「用來偵測的那一幀」拿去顯示,
//     確保畫面與手部骨架永遠對應同一張原始 JPEG。
// ══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'mediapipe_service.dart';
import 'pi_camera_source.dart' show PiConnectionStatus;

class PiHandSource {
  final String ip;
  final int port;
  final MediaPipeService service;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _processing = false;
  bool _disposed = false;
  bool _running = false;
  Uint8List? _latestPending;
  final ValueNotifier<PiConnectionStatus> status = ValueNotifier(PiConnectionStatus.disconnected);

  void _setStatus(PiConnectionStatus value) {
    if (_disposed) return;
    status.value = value;
    connected.value = value == PiConnectionStatus.connected;
  }

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
    if (_disposed || _running) return;
    _running = true;
    _setStatus(PiConnectionStatus.connecting);

    final uri = Uri.parse('ws://$ip:$port');
    try {
      _channel = WebSocketChannel.connect(uri);
    } catch (e) {
      debugPrint('PiHandSource 連線失敗: $e');
      _setStatus(PiConnectionStatus.failed);
      return;
    }

    _sub = _channel!.stream.listen(
      _onData,
      onError: (e) {
        debugPrint('PiHandSource stream 錯誤: $e');
        _setStatus(PiConnectionStatus.failed);
      },
      onDone: () {
        if (_running && status.value != PiConnectionStatus.failed) _setStatus(PiConnectionStatus.disconnected);
      },
      cancelOnError: false,
    );

    try {
      await _channel!.ready.timeout(const Duration(seconds: 8));
      if (_running) _setStatus(PiConnectionStatus.connected);
    } catch (error) {
      debugPrint('Pi WebSocket handshake failed: $error');
      _setStatus(PiConnectionStatus.failed);
      await _sub?.cancel().timeout(const Duration(seconds: 1), onTimeout: () {});
      await _channel?.sink.close().timeout(const Duration(seconds: 1), onTimeout: () {});
      _running = false;
    }
  }

  void _onData(dynamic data) {
    if (_disposed || !_running) return;
    if (data is! Uint8List) return;

    // Keep at most one pending JPEG, without publishing ahead of detection.
    // 寧可跳過幾幀讓畫面稍微不那麼即時,也不能讓畫面先跑掉、
    // 手部骨架卻停在舊的一幀 —— 那才是「對不上」的真正成因。
    if (_processing) { _latestPending = data; return; }
    _processing = true;

    _decodeSizeAndDetectThenDisplay(data).whenComplete(() {
      _processing = false;
      final next = _latestPending;
      _latestPending = null;
      if (next != null && _running && !_disposed) _onData(next);
    });
  }

  Future<void> _decodeSizeAndDetectThenDisplay(Uint8List jpegBytes) async {
    try {
      final size = await _decodeImageSize(jpegBytes);

      final result = await service.detectHandInImage(
        jpegBytes,
        isMirror: false, // 樹莓派鏡頭固定架設,通常不需要鏡像
      );

      // 🚀 修正:偵測結果、畫面、尺寸三者一起更新,鎖同一幀,
      // 確保 UI 疊圖時三者永遠對應同一張原始 JPEG,徹底消除時間差。
      if (!_disposed && _running) {
        if (size != null) frameSize.value = size;
        handResult.value = result;
        latestJpeg.value = jpegBytes;
      }
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
      codec.dispose();
      return size;
    } catch (e) {
      return null;
    }
  }

  Future<void> stop() async {
    _running = false;
    _latestPending = null;
    _setStatus(PiConnectionStatus.disconnected);
    await _sub?.cancel().timeout(const Duration(seconds: 1), onTimeout: () {});
    await _channel?.sink.close().timeout(const Duration(seconds: 1), onTimeout: () {});
    _sub = null;
    _channel = null;
    if (!_disposed) connected.value = false;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stop();
    status.dispose();
    connected.dispose();
    latestJpeg.dispose();
    frameSize.dispose();
    handResult.dispose();
  }
}