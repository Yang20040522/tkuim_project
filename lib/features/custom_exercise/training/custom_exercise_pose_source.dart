import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../../../models/pose_data.dart';
import '../../../services/body_pose_engine.dart';

abstract class CustomExercisePoseSource {
  ValueListenable<PoseData> get pose;
  ValueListenable<bool> get cameraReady;
  CameraController? get cameraController;
  bool get isFrontCamera;

  Future<void> initialize();
  Future<void> pause();
  Future<void> resume();
  Future<void> switchCamera();
  Future<void> dispose();
}

/// The single owner of CameraController and RTMPose for CUSTOM training.
class BodyPoseCustomExerciseSource implements CustomExercisePoseSource {
  BodyPoseCustomExerciseSource({BodyPoseEngine? engine})
      : _engine = engine ?? BodyPoseEngine();

  final BodyPoseEngine _engine;
  bool _initialized = false;

  @override
  ValueListenable<PoseData> get pose => _engine.poseNotifier;

  @override
  ValueListenable<bool> get cameraReady => _engine.cameraReady;

  @override
  CameraController? get cameraController => _engine.cameraController;

  @override
  bool get isFrontCamera => _engine.isFrontCamera;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await _engine.init();
    await _engine.startCamera();
    _initialized = true;
  }

  @override
  Future<void> pause() => _engine.stopCamera();

  @override
  Future<void> resume() => _engine.startCamera();

  @override
  Future<void> switchCamera() => _engine.switchCamera();

  @override
  Future<void> dispose() => _engine.dispose();
}
