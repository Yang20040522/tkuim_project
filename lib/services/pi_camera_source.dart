// lib/services/pi_camera_source.dart
//
// ══════════════════════════════════════════════════════════════════
//  樹莓派外接鏡頭來源
//  - 透過 WebSocket 連線樹莓派的 camera_server.py (ws://<pi_ip>:8765)
//  - 預覽直接顯示 JPEG；解碼和 RTMPose 在獨立的 latest-frame 推論路徑
//
//  frameSize — 從 JPEG header 讀取原始 pixel 尺寸,跟
//     latestJpeg 同一幀更新。畫面顯示是用 Image.memory(fit: BoxFit.cover)
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
  disconnected('未連線'),
  connecting('連線中'),
  connected('已連線'),
  failed('連線失敗，請重新連線');

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
  Timer? _inferenceTimer;
  DateTime? _lastInferenceStart;
  int _generation = 0;
  static const _inferenceInterval = Duration(milliseconds: 125);
  final ValueNotifier<PiConnectionStatus> status = ValueNotifier(
    PiConnectionStatus.disconnected,
  );

  void _setStatus(PiConnectionStatus value) {
    if (_disposed) return;
    status.value = value;
    connected.value = value == PiConnectionStatus.connected;
  }

  final ValueNotifier<bool> connected = ValueNotifier(false);
  final ValueNotifier<Uint8List?> latestJpeg = ValueNotifier(null);
  // 🚀 新增:原始畫面實際尺寸,跟 latestJpeg 鎖同一幀
  final ValueNotifier<Size?> frameSize = ValueNotifier(null);

  PiCameraSource({required this.engine, required this.ip, this.port = 8765});

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
      _invalidateFrames();
      return;
    }

    _sub = _channel!.stream.listen(
      _onData,
      onError: (e) {
        debugPrint('PiCameraSource stream 錯誤: $e');
        _running = false;
        _invalidateFrames();
        _setStatus(PiConnectionStatus.failed);
      },
      onDone: () {
        _running = false;
        _invalidateFrames();
        if (!_disposed && status.value != PiConnectionStatus.failed) {
          _setStatus(PiConnectionStatus.disconnected);
        }
      },
      cancelOnError: false,
    );

    try {
      await _channel!.ready.timeout(const Duration(seconds: 8));
      if (_running) _setStatus(PiConnectionStatus.connected);
    } catch (error) {
      debugPrint('Pi WebSocket handshake failed: $error');
      _setStatus(PiConnectionStatus.failed);
      await _sub?.cancel().timeout(
            const Duration(seconds: 1),
            onTimeout: () {},
          );
      await _channel?.sink.close().timeout(
            const Duration(seconds: 1),
            onTimeout: () {},
          );
      _running = false;
      _invalidateFrames();
    }
  }

  void _onData(dynamic data) {
    if (_disposed || !_running) return;
    if (data is! Uint8List) return;

    final size = _jpegSize(data);
    if (size != null) frameSize.value = size;
    latestJpeg.value = data;
    _latestPending = data;
    _scheduleInference();
  }

  void _scheduleInference() {
    if (_disposed ||
        !_running ||
        _processing ||
        _inferenceTimer != null ||
        _latestPending == null) {
      return;
    }
    final elapsed = _lastInferenceStart == null
        ? _inferenceInterval
        : DateTime.now().difference(_lastInferenceStart!);
    final delay = _inferenceInterval - elapsed;
    if (delay > Duration.zero) {
      _inferenceTimer = Timer(delay, () {
        _inferenceTimer = null;
        _scheduleInference();
      });
      return;
    }
    final jpeg = _latestPending!;
    _latestPending = null;
    _processing = true;
    _lastInferenceStart = DateTime.now();
    final generation = _generation;
    _decodeAndInfer(jpeg, generation).whenComplete(() {
      _processing = false;
      _scheduleInference();
    });
  }

  bool _isCurrent(int generation) =>
      !_disposed && _running && generation == _generation;

  Future<void> _decodeAndInfer(Uint8List jpegBytes, int generation) async {
    try {
      final frame = await compute(_decodeRgb, jpegBytes);
      if (frame == null || !_isCurrent(generation)) return;

      await engine.processExternalFrame(
        frame.rgb,
        frame.width,
        frame.height,
        isMirror: false,
        needsRotation: false, // 樹莓派畫面本身是正的,不能套用手機鏡頭的 90 度校正映射
        shouldPublish: () => _isCurrent(generation),
      );
    } catch (e) {
      debugPrint('PiCameraSource 解碼/推論錯誤: $e');
    }
  }

  Future<void> stop() async {
    _running = false;
    _invalidateFrames();
    _setStatus(PiConnectionStatus.disconnected);
    await _sub?.cancel().timeout(const Duration(seconds: 1), onTimeout: () {});
    await _channel?.sink.close().timeout(
          const Duration(seconds: 1),
          onTimeout: () {},
        );
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

  void _invalidateFrames() {
    _generation++;
    _latestPending = null;
    _inferenceTimer?.cancel();
    _inferenceTimer = null;
  }
}

class _RgbFrame {
  final Uint8List rgb;
  final int width;
  final int height;
  _RgbFrame(this.rgb, this.width, this.height);
}

_RgbFrame? _decodeRgb(Uint8List jpeg) {
  final decoded = img.decodeJpg(jpeg);
  if (decoded == null) return null;
  final rgb = decoded.convert(numChannels: 3);
  return _RgbFrame(rgb.toUint8List(), rgb.width, rgb.height);
}

// SOF markers contain dimensions; scanning the JPEG header avoids a UI-isolate decode.
Size? _jpegSize(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xff || bytes[1] != 0xd8) return null;
  var index = 2;
  while (index + 9 < bytes.length && bytes[index] == 0xff) {
    final marker = bytes[index + 1];
    if (marker == 0xda || marker == 0xd9) break;
    final length = (bytes[index + 2] << 8) | bytes[index + 3];
    if (length < 2 || index + 2 + length > bytes.length) break;
    if ((marker >= 0xc0 && marker <= 0xc3) ||
        (marker >= 0xc5 && marker <= 0xc7) ||
        (marker >= 0xc9 && marker <= 0xcb) ||
        (marker >= 0xcd && marker <= 0xcf)) {
      final height = (bytes[index + 5] << 8) | bytes[index + 6];
      final width = (bytes[index + 7] << 8) | bytes[index + 8];
      return Size(width.toDouble(), height.toDouble());
    }
    index += 2 + length;
  }
  return null;
}
