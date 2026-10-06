import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/body_pose_observation.dart';
import '../features/rehab_ml/body_research_context.dart' show newResearchId;
import 'body_pose_engine.dart';

enum PiConnectionStatus {
  disconnected,
  connecting,
  connected,
  failed;

  String get label => switch (this) {
        disconnected => '未連線',
        connecting => '連線中…',
        connected => '已連線',
        failed => '連線失敗',
      };
}

class PiRgbFrame {
  const PiRgbFrame(this.rgb, this.width, this.height);
  final Uint8List rgb;
  final int width, height;
}

/// Atomic packet: JPEG, overlay and research refer to one processed frame.
class PiProcessedFrame {
  PiProcessedFrame(Uint8List jpeg, this.observation)
      : _jpeg = List<int>.unmodifiable(jpeg);
  final List<int> _jpeg;
  Uint8List get jpeg => Uint8List.fromList(_jpeg);
  final BodyPoseObservation observation;
}

typedef PiFrameInference = Future<BodyPoseObservation?> Function(
    PiRgbFrame rgb, BodyFrameIdentity identity, bool Function() stillCurrent);

class PiCameraSource {
  PiCameraSource({
    BodyPoseEngine? engine,
    required this.ip,
    this.port = 8765,
    WebSocketChannel Function(Uri)? connect,
    Future<PiRgbFrame?> Function(Uint8List)? decode,
    PiFrameInference? infer,
    this.minimumInterval = const Duration(milliseconds: 125),
    this.handshakeTimeout = const Duration(seconds: 8),
  })  : _engine = engine,
        _connect = connect ?? WebSocketChannel.connect,
        _decode = decode ?? ((bytes) => compute(_decodeRgb, bytes)),
        _infer = infer {
    if (engine == null && infer == null) {
      throw ArgumentError('Inference source required');
    }
  }
  final String ip;
  final int port;
  final BodyPoseEngine? _engine;
  final WebSocketChannel Function(Uri) _connect;
  final Future<PiRgbFrame?> Function(Uint8List) _decode;
  final PiFrameInference? _infer;
  final Duration minimumInterval, handshakeTimeout;
  final ValueNotifier<bool> connected = ValueNotifier(false);
  final ValueNotifier<PiConnectionStatus> connectionStatus =
      ValueNotifier(PiConnectionStatus.disconnected);
  ValueNotifier<PiConnectionStatus> get status => connectionStatus;
  final ValueNotifier<Uint8List?> latestJpeg = ValueNotifier(null);
  final ValueNotifier<Size?> frameSize = ValueNotifier(null);
  final ValueNotifier<PiProcessedFrame?> processedFrame = ValueNotifier(null);
  final Stopwatch _clock = Stopwatch()..start();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _throttle;
  _PendingFrame? _pending;
  bool _disposed = false, _running = false, _processing = false;
  int _generation = 0, _serial = 0, _lastStartedMs = -125;
  String _sessionId = '';
  bool _current(int generation) =>
      !_disposed && _running && generation == _generation;

  Future<void> start() async {
    if (_disposed || _running) return;
    _running = true;
    final generation = ++_generation;
    _sessionId = newResearchId();
    _serial = 0;
    connectionStatus.value = PiConnectionStatus.connecting;
    try {
      final channel = _connect(Uri.parse('ws://$ip:$port'));
      _channel = channel;
      _sub = channel.stream.listen((data) => _onData(data, generation),
          onError: (Object _) => _failed(generation),
          onDone: () => _failed(generation));
      await channel.ready.timeout(handshakeTimeout);
      if (!_current(generation)) return;
      connected.value = true;
      connectionStatus.value = PiConnectionStatus.connected;
    } catch (_) {
      if (!_current(generation)) return;
      await stop();
      if (!_disposed && !_running) {
        connectionStatus.value = PiConnectionStatus.failed;
      }
    }
  }

  void _failed(int generation) {
    if (!_current(generation)) return;
    unawaited(stop().then((_) {
      if (!_disposed && !_running) {
        connectionStatus.value = PiConnectionStatus.failed;
      }
    }));
  }

  void _onData(dynamic data, int generation) {
    if (!_current(generation) || data is! List<int> || data.isEmpty) return;
    _pending = _PendingFrame(
        Uint8List.fromList(data),
        BodyFrameIdentity(
            frameId: _serial++,
            streamSessionId: _sessionId,
            receivedAtMs: _clock.elapsedMilliseconds),
        generation);
    _schedule();
  }

  void _schedule() {
    if (_disposed ||
        !_running ||
        _processing ||
        _pending == null ||
        _throttle != null) {
      return;
    }
    final remaining = minimumInterval.inMilliseconds -
        (_clock.elapsedMilliseconds - _lastStartedMs);
    if (remaining > 0) {
      _throttle = Timer(Duration(milliseconds: remaining), () {
        _throttle = null;
        _schedule();
      });
      return;
    }
    final frame = _pending!;
    _pending = null;
    _processing = true;
    _lastStartedMs = _clock.elapsedMilliseconds;
    unawaited(_process(frame).whenComplete(() {
      _processing = false;
      _schedule();
    }));
  }

  Future<void> _process(_PendingFrame frame) async {
    bool current() => _current(frame.generation);
    try {
      final rgb = await _decode(frame.jpeg);
      if (!current() || rgb == null) return;
      void publish(BodyPoseObservation observation) {
        if (!current() ||
            observation.streamSessionId != frame.identity.streamSessionId ||
            observation.frameId != frame.identity.frameId) {
          return;
        }
        frameSize.value = Size(rgb.width.toDouble(), rgb.height.toDouble());
        latestJpeg.value = frame.jpeg;
        processedFrame.value = PiProcessedFrame(frame.jpeg, observation);
      }

      if (_infer != null) {
        final observation = await _infer!(rgb, frame.identity, current);
        if (observation != null) publish(observation);
      } else {
        await _engine!.processExternalFrame(rgb.rgb, rgb.width, rgb.height,
            isMirror: false,
            needsRotation: false,
            identity: frame.identity,
            shouldPublish: current,
            onObservation: publish);
      }
    } catch (_) {
      if (current()) debugPrint('Pi camera frame decode/inference unavailable');
    }
  }

  Future<void> waitForFirstFrame(
      {Duration timeout = const Duration(seconds: 10)}) async {
    if (processedFrame.value != null) return;
    final completer = Completer<void>();
    void listener() {
      if (processedFrame.value != null && !completer.isCompleted) {
        completer.complete();
      }
    }

    processedFrame.addListener(listener);
    try {
      await completer.future.timeout(timeout);
    } finally {
      if (!_disposed) processedFrame.removeListener(listener);
    }
  }

  Future<void> stop() async {
    _running = false;
    ++_generation;
    _pending = null;
    _throttle?.cancel();
    _throttle = null;
    final sub = _sub, channel = _channel;
    _sub = null;
    _channel = null;
    if (!_disposed) {
      connected.value = false;
      connectionStatus.value = PiConnectionStatus.disconnected;
      processedFrame.value = null;
      latestJpeg.value = null;
      frameSize.value = null;
    }
    try {
      await sub?.cancel().timeout(const Duration(seconds: 1));
    } catch (_) {}
    try {
      await channel?.sink.close().timeout(const Duration(seconds: 1));
    } catch (_) {}
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(stop());
    connected.dispose();
    connectionStatus.dispose();
    latestJpeg.dispose();
    frameSize.dispose();
    processedFrame.dispose();
  }
}

class _PendingFrame {
  const _PendingFrame(this.jpeg, this.identity, this.generation);
  final Uint8List jpeg;
  final BodyFrameIdentity identity;
  final int generation;
}

PiRgbFrame? _decodeRgb(Uint8List bytes) {
  final image = img.decodeJpg(bytes)?.convert(numChannels: 3);
  return image == null
      ? null
      : PiRgbFrame(image.toUint8List(), image.width, image.height);
}
