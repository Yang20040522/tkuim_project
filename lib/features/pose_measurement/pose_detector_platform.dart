import 'package:flutter/services.dart';

/// Per-PlatformView boundary. Only Android owns camera frames and inference.
abstract interface class PoseDetectorPlatform {
  Stream<Map<dynamic, dynamic>> get events;
  Future<void> start();
  Future<void> stop();
}

class MethodChannelPoseDetectorPlatform implements PoseDetectorPlatform {
  MethodChannelPoseDetectorPlatform(int viewId)
      : _control = MethodChannel(
          'com.rehabassist/pose_measurement/$viewId/control',
        ),
        _events = EventChannel(
          'com.rehabassist/pose_measurement/$viewId/events',
        );

  final MethodChannel _control;
  final EventChannel _events;

  @override
  late final Stream<Map<dynamic, dynamic>> events = _events
      .receiveBroadcastStream()
      .map((event) => Map<dynamic, dynamic>.from(event as Map));

  @override
  Future<void> start() => _control.invokeMethod<void>('start');

  @override
  Future<void> stop() => _control.invokeMethod<void>('stop');
}
