// lib/services/pi_camera_source.dart
//
// ══════════════════════════════════════════════════════════════════
//  樹莓派外接鏡頭來源
//  - 透過 WebSocket 連線樹莓派的 camera_server.py (ws://<pi_ip>:8765)
//  - 收到 JPEG bytes → 解碼成 RGB → 餵進 BodyPoseEngine.processExternalFrame
//
//  🚀 修正:畫面顯示與骨架計算必須「鎖同一幀」,否則骨架會對不上畫面。
//     原本邏輯是「新幀一到就立刻顯示,但推論忙碌時就丟棄該幀」,
//     導致顯示的畫面已經跑到後面幾幀,骨架卻還是舊幀的位置,
//     動作快的時候特別明顯。
//     改成:先完成推論,再把「用來推論的那一幀」拿去顯示,
//     確保畫面與骨架永遠對應同一張原始 JPEG。
//
//  🚀 新增:frameSize — 紀錄原始 JPEG 的實際 pixel 尺寸,並跟
//     latestJpeg 鎖同一幀更新。畫面顯示是用 Image.memory(fit: BoxFit.cover)
//     塞進跟原始畫面長寬比不同的容器,骨架 painter 需要這個尺寸,
//     才能算出跟 BoxFit.cover 一致的縮放/裁切偏移,讓骨架貼合畫面
//     (詳見 body_training_screen.dart 的 _SkeletonPainter)。
// ══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'body_pose_engine.dart';

enum PiConnectionStatus {
  disconnected('未連線'), connecting('連線中'), connected('已連線'), failed('連線失敗，請重新連線');
  final String label;
  const PiConnectionStatus(this.label);
}

class PiCameraSource {
  final String ip;
  final int port;
  final BodyPoseEngine engine;

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
  // 🚀 新增:原始畫面實際尺寸,跟 latestJpeg 鎖同一幀
  final ValueNotifier<Size?> frameSize = ValueNotifier(null);

  PiCameraSource({
    required this.engine,
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
      debugPrint('PiCameraSource 連線失敗: $e');
      _setStatus(PiConnectionStatus.failed);
      return;
    }

    _sub = _channel!.stream.listen(
      _onData,
      onError: (e) {
        debugPrint('PiCameraSource stream 錯誤: $e');
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

    // Keep at most one pending JPEG; newer frames replace it while inference runs.
    // 寧可跳過幾幀讓畫面稍微不那麼即時,也不能讓畫面先跑掉、
    // 骨架卻停在舊的一幀 —— 那才是「對不上」的真正成因。
    if (_processing) { _latestPending = data; return; }
    _processing = true;

    _decodeAndInferThenDisplay(data).whenComplete(() {
      _processing = false;
      final next = _latestPending;
      _latestPending = null;
      if (next != null && _running && !_disposed) _onData(next);
    });
  }

  Future<void> _decodeAndInferThenDisplay(Uint8List jpegBytes) async {
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

      // 🚀 修正:骨架算完之後,才把「這一張」JPEG 拿去顯示。
      // 確保畫面永遠跟 poseNotifier 剛更新的骨架是同一幀,徹底消除時間差。
      // 🚀 新增:frameSize 在 latestJpeg 之前寫入,確保 latestJpeg 的
      // listener 觸發時,frameSize.value 一定已經是同一幀的最新值。
      if (!_disposed && _running) {
        frameSize.value =
            Size(rgbImage.width.toDouble(), rgbImage.height.toDouble());
        latestJpeg.value = jpegBytes;
      }
    } catch (e) {
      debugPrint('PiCameraSource 解碼/推論錯誤: $e');
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
    frameSize.dispose(); // 🚀 新增
  }
}