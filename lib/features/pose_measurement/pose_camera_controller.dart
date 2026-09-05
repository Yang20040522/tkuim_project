import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/pose_frame.dart';
import 'pose_detector_platform.dart';

enum PoseCameraPermission { granted, denied, permanentlyDenied }

enum PoseCameraState {
  initializing,
  loadingModel,
  ready,
  noPose,
  detected,
  permissionDenied,
  permissionPermanentlyDenied,
  paused,
  unavailable,
  error;

  String get label => switch (this) {
        initializing => '正在初始化相機…',
        loadingModel => '正在載入人體姿勢模型…',
        ready => '相機已就緒，請讓完整人體進入畫面',
        noPose => '尚未偵測到人體，請讓完整人體進入畫面',
        detected => '已偵測到人體',
        permissionDenied => '尚未允許相機權限，無法進行姿勢量測',
        permissionPermanentlyDenied => '相機權限已關閉，請至系統設定允許使用相機',
        paused => '姿勢量測已暫停',
        unavailable => '目前無法使用前置相機進行姿勢量測',
        error => '姿勢量測發生問題，請重試',
      };
}

typedef PoseDetectorPlatformFactory = PoseDetectorPlatform Function(int viewId);
typedef PosePermissionRequest = Future<PoseCameraPermission> Function();

/// Coordinates one native pipeline; never acquires a Flutter CameraController.
/// Commands are serialized and each async continuation belongs to a generation.
class PoseCameraController {
  PoseCameraController({
    PoseDetectorPlatformFactory? platformFactory,
    PosePermissionRequest? requestPermission,
  })  : _platformFactory =
            platformFactory ?? MethodChannelPoseDetectorPlatform.new,
        _requestPermission = requestPermission ?? _requestCameraPermission;

  final PoseDetectorPlatformFactory _platformFactory;
  final PosePermissionRequest _requestPermission;
  final ValueNotifier<PoseCameraState> state =
      ValueNotifier(PoseCameraState.initializing);
  final ValueNotifier<PoseFrame?> frame = ValueNotifier(null);

  PoseDetectorPlatform? _platform;
  StreamSubscription<Map<dynamic, dynamic>>? _subscription;
  Future<PoseCameraPermission>? _permissionRequest;
  Future<void> _commands = Future.value();
  int _generation = 0;
  bool _active = false;
  bool _disposed = false;

  static Future<PoseCameraPermission> _requestCameraPermission() async {
    final permission = await Permission.camera.request();
    if (permission.isGranted) return PoseCameraPermission.granted;
    if (permission.isPermanentlyDenied || permission.isRestricted) {
      return PoseCameraPermission.permanentlyDenied;
    }
    return PoseCameraPermission.denied;
  }

  void attach(int viewId) {
    if (_disposed) return;
    _stopSession();
    _platform = _platformFactory(viewId);
    if (_active) unawaited(_startSession());
  }

  void setActive(bool value) {
    if (_disposed || value == _active) return;
    _active = value;
    if (value) {
      if (_platform != null) unawaited(_startSession());
    } else {
      _stopSession();
      state.value = PoseCameraState.paused;
    }
  }

  void markUnavailable() {
    if (_disposed) return;
    _stopSession();
    state.value = PoseCameraState.unavailable;
  }

  void retry() {
    if (_disposed || !_active || _platform == null) return;
    _stopSession();
    unawaited(_startSession());
  }

  bool _current(int generation) =>
      !_disposed && _active && generation == _generation;

  Future<void> _startSession() async {
    final platform = _platform;
    if (platform == null || !_active || _disposed) return;
    final generation = ++_generation;
    state.value = PoseCameraState.initializing;
    try {
      // Permission dialogs temporarily inactivate the app. Reuse the same
      // in-flight request after resume, but only the newest generation starts.
      final request = _permissionRequest ??= _requestPermission();
      final permission = await request;
      if (identical(_permissionRequest, request)) _permissionRequest = null;
      if (!_current(generation)) return;
      if (permission != PoseCameraPermission.granted) {
        state.value = permission == PoseCameraPermission.permanentlyDenied
            ? PoseCameraState.permissionPermanentlyDenied
            : PoseCameraState.permissionDenied;
        return;
      }
      _subscription = platform.events.listen(
        (event) {
          if (_current(generation)) _handleEvent(event);
        },
        onError: (Object error) {
          if (_current(generation)) _failSession();
        },
        onDone: () {
          if (_current(generation)) _failSession();
        },
      );
      await _enqueue(() async {
        if (_current(generation)) await platform.start();
      });
    } on Object {
      _permissionRequest = null;
      if (_current(generation)) _failSession();
    }
  }

  void _handleEvent(Map<dynamic, dynamic> event) {
    if (event['type'] == 'state') {
      final next = switch (event['state']) {
        'initializing' => PoseCameraState.initializing,
        'loadingModel' => PoseCameraState.loadingModel,
        'ready' => PoseCameraState.ready,
        'unavailable' => PoseCameraState.unavailable,
        'error' => PoseCameraState.error,
        _ => null,
      };
      if (next == null) return;
      if (next == PoseCameraState.error ||
          next == PoseCameraState.unavailable) {
        _stopSession();
      }
      state.value = next;
    } else if (event['type'] == 'frame') {
      try {
        final next = PoseFrame.fromPlatform(event);
        frame.value = next;
        state.value =
            next.hasPose ? PoseCameraState.detected : PoseCameraState.noPose;
      } on Object {
        _failSession();
      }
    }
  }

  void _failSession() {
    _stopSession();
    state.value = PoseCameraState.error;
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _commands.then((_) => operation());
    // Keep teardown available even after a failed start or a disposed view.
    _commands = next.catchError((Object _) {});
    return next;
  }

  void _stopSession() {
    ++_generation;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    frame.value = null;
    final platform = _platform;
    if (platform != null) {
      unawaited(_enqueue(platform.stop).catchError((Object _) {}));
    }
  }

  /// Native PlatformView disposal independently closes the same resources.
  /// No async callback may notify these notifiers after this method returns.
  void dispose() {
    if (_disposed) return;
    _stopSession();
    _active = false;
    _disposed = true;
    state.dispose();
    frame.dispose();
  }
}
