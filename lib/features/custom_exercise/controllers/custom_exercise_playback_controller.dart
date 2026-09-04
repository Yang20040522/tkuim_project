import 'package:flutter/foundation.dart';

import '../../../models/custom_rehab_exercise.dart';
import '../../../models/joint_definition.dart';
import '../../../models/joint_rotation.dart';
import '../../../models/joint_type.dart';

enum CustomExercisePlaybackStatus { stopped, playing, paused }

class CustomExercisePlaybackController extends ChangeNotifier {
  final CustomRehabExercise exercise;
  CustomExercisePlaybackStatus _status = CustomExercisePlaybackStatus.stopped;
  double _playbackTime = 0;

  CustomExercisePlaybackController({required this.exercise});

  CustomExercisePlaybackStatus get status => _status;
  double get playbackTime => _playbackTime;
  bool get canPlay => exercise.keyframes.length >= 2;
  bool get isCompleted =>
      _status == CustomExercisePlaybackStatus.stopped &&
      exercise.duration > 0 &&
      _playbackTime >= exercise.duration;

  Map<JointType, JointRotation> get restingPose {
    final firstPose = exercise.keyframes.isEmpty
        ? const <JointType, JointRotation>{}
        : exercise.keyframes.first.jointRotations;
    return {
      for (final definition in JointDefinitions.all)
        definition.type: firstPose[definition.type] ??
            DefaultPose.rotationOf(definition.type),
    };
  }

  void play() {
    if (!canPlay || _status == CustomExercisePlaybackStatus.playing) return;
    if (_status == CustomExercisePlaybackStatus.paused) {
      resume();
      return;
    }
    _playbackTime = 0;
    _status = CustomExercisePlaybackStatus.playing;
    notifyListeners();
  }

  void pause() {
    if (_status != CustomExercisePlaybackStatus.playing) return;
    _status = CustomExercisePlaybackStatus.paused;
    notifyListeners();
  }

  void resume() {
    if (_status != CustomExercisePlaybackStatus.paused) return;
    _status = CustomExercisePlaybackStatus.playing;
    notifyListeners();
  }

  void stop() {
    if (_status == CustomExercisePlaybackStatus.stopped && _playbackTime == 0) {
      return;
    }
    _status = CustomExercisePlaybackStatus.stopped;
    _playbackTime = 0;
    notifyListeners();
  }

  void updateProgress(double time) {
    if (_status == CustomExercisePlaybackStatus.stopped || !time.isFinite) {
      return;
    }
    final safeTime = time.clamp(0, exercise.duration).toDouble();
    if (safeTime == _playbackTime) return;
    _playbackTime = safeTime;
    notifyListeners();
  }

  void complete() {
    if (_status == CustomExercisePlaybackStatus.stopped) return;
    _status = CustomExercisePlaybackStatus.stopped;
    _playbackTime = exercise.duration;
    notifyListeners();
  }
}
