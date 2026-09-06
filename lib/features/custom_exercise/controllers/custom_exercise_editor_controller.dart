import 'package:flutter/foundation.dart';

import '../../../models/custom_rehab_exercise.dart';
import '../../../models/exercise_keyframe.dart';
import '../../../models/joint_definition.dart';
import '../../../models/joint_rotation.dart';
import '../../../models/joint_type.dart';
import '../../pose_measurement/evaluation/pose_measurement_rule.dart';
import '../services/custom_exercise_bone_mapping.dart';
import 'custom_exercise_playback_controller.dart';

/// 自訂動作編輯器的單一狀態來源。
///
/// 草稿資料與目前編輯姿勢的單一狀態來源。
class CustomExerciseEditorController extends ChangeNotifier {
  CustomRehabExercise _draft;
  JointType _selectedJoint = JointType.rightShoulder;
  final Map<JointType, JointRotation> _currentPose = {
    for (final joint in CustomExerciseBoneMapping.controllableJoints)
      joint: JointRotation.zero,
  };
  String? _selectedKeyframeId;
  CustomExercisePlaybackStatus _playbackStatus =
      CustomExercisePlaybackStatus.stopped;
  double _playbackTime = 0;
  int _nextKeyframeSequence = 1;
  final bool isEditing;
  late double _animationDurationSeconds;
  bool _hasConfiguredAnimationDuration = false;

  CustomExerciseEditorController({
    CustomRehabExercise? initialExercise,
    String? therapistId,
    DateTime? now,
  })  : isEditing = initialExercise != null,
        _draft = initialExercise ??
            _createDraft(
              therapistId: therapistId,
              now: now ?? DateTime.now(),
            ) {
    _animationDurationSeconds = _draft.duration > 0 ? _draft.duration : 5;
    if (_draft.keyframes.isNotEmpty) {
      final firstKeyframe = _draft.keyframes.first;
      _loadPose(firstKeyframe.jointRotations);
      _selectedKeyframeId = firstKeyframe.id;
      _playbackTime = firstKeyframe.time;
    }
  }

  CustomRehabExercise get draft => _draft;
  JointType get selectedJoint => _selectedJoint;
  List<JointType> get controllableJoints =>
      CustomExerciseBoneMapping.controllableJoints;
  Map<JointType, JointRotation> get currentPose =>
      Map.unmodifiable(_currentPose);
  JointRotation get selectedJointRotation =>
      _currentPose[_selectedJoint] ?? DefaultPose.rotationOf(_selectedJoint);
  List<ExerciseKeyframe> get keyframes => _draft.keyframes;
  String? get selectedKeyframeId => _selectedKeyframeId;
  CustomExercisePlaybackStatus get playbackStatus => _playbackStatus;
  double get playbackTime => _playbackTime;
  bool get canPlay => _draft.keyframes.length >= 2;
  double get animationDurationSeconds => _animationDurationSeconds;

  List<PoseMeasurementRule> get poseMeasurementRules =>
      _draft.poseMeasurementRules;

  String? get saveValidationError {
    if (_draft.name.trim().isEmpty) {
      return '請輸入動作名稱';
    }
    if (_draft.keyframes.length < 2) {
      return '至少需要 2 個 Keyframes 才能儲存';
    }
    final settingsError = trainingSettingsValidationError;
    if (settingsError != null) return settingsError;
    if (_draft.duration != _draft.keyframes.last.time) {
      return 'Keyframes 與 duration 不一致';
    }
    final measurements = <Object>{};
    for (final rule in _draft.poseMeasurementRules) {
      final error = rule.validationError;
      if (error != null) return error;
      if (!measurements.add(rule.measurement)) {
        return '${rule.measurement.poseRuleLabel}已經有一條評估規則';
      }
    }
    try {
      CustomRehabExercise.fromJson(_draft.toJson());
    } on FormatException {
      return '動作資料格式無效，請檢查 Keyframes';
    } on ArgumentError {
      return '動作資料格式無效，請檢查 Keyframes';
    }
    return null;
  }

  void selectJoint(JointType joint) {
    if (!CustomExerciseBoneMapping.controllableJoints.contains(joint)) {
      throw UnsupportedError('${joint.name} 尚未在目前批次開放控制');
    }
    if (_selectedJoint == joint) return;
    _stopPlaybackState();
    _selectedJoint = joint;
    notifyListeners();
  }

  void updateSelectedJointRotation(JointRotation rotation) {
    final definition = JointDefinitions.of(_selectedJoint);
    final safeRotation = JointRotation(
      x: rotation.x
          .clamp(definition.xRange.min, definition.xRange.max)
          .toDouble(),
      y: rotation.y
          .clamp(definition.yRange.min, definition.yRange.max)
          .toDouble(),
      z: rotation.z
          .clamp(definition.zRange.min, definition.zRange.max)
          .toDouble(),
    );
    var changed = _stopPlaybackState();
    if (_selectedKeyframeId != null) {
      _selectedKeyframeId = null;
      changed = true;
    }
    if (safeRotation != selectedJointRotation) {
      _currentPose[_selectedJoint] = safeRotation;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void resetSelectedJointRotation() {
    updateSelectedJointRotation(DefaultPose.rotationOf(_selectedJoint));
  }

  void resetAllJointRotations() {
    var changed = _stopPlaybackState();
    if (_selectedKeyframeId != null) {
      _selectedKeyframeId = null;
      changed = true;
    }
    for (final joint in CustomExerciseBoneMapping.controllableJoints) {
      final defaultRotation = DefaultPose.rotationOf(joint);
      if (_currentPose[joint] != defaultRotation) {
        _currentPose[joint] = defaultRotation;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void addKeyframeFromCurrentPose() {
    _stopPlaybackState();
    final time =
        _draft.keyframes.isEmpty ? 0.0 : _draft.keyframes.last.time + 1.0;
    final keyframe = ExerciseKeyframe(
      id: _createKeyframeId(),
      time: time,
      jointRotations: _completePose(_currentPose),
    );
    final keyframes = [..._draft.keyframes, keyframe];
    final timedKeyframes =
        _hasConfiguredAnimationDuration && keyframes.length >= 2
            ? _scaleKeyframesToDuration(keyframes, _animationDurationSeconds)
            : keyframes;
    final duration = timedKeyframes.isEmpty ? 0.0 : timedKeyframes.last.time;
    if (!_hasConfiguredAnimationDuration) {
      _animationDurationSeconds = duration;
    }
    _draft = _draft.copyWith(
      duration: duration,
      keyframes: timedKeyframes,
      updatedAt: DateTime.now(),
    );
    _selectedKeyframeId = keyframe.id;
    _playbackTime = 0;
    notifyListeners();
  }

  void selectKeyframe(String id) {
    final index = _draft.keyframes.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final keyframe = _draft.keyframes[index];
    _stopPlaybackState();
    _loadPose(keyframe.jointRotations);
    _selectedKeyframeId = keyframe.id;
    _playbackTime = keyframe.time;
    notifyListeners();
  }

  void deleteKeyframe(String id) {
    final removedIndex = _draft.keyframes.indexWhere((item) => item.id == id);
    if (removedIndex < 0) return;

    _stopPlaybackState();
    final remaining = List<ExerciseKeyframe>.of(_draft.keyframes)
      ..removeAt(removedIndex);
    final timedRemaining =
        _hasConfiguredAnimationDuration && remaining.length >= 2
            ? _scaleKeyframesToDuration(remaining, _animationDurationSeconds)
            : remaining.length < 2
                ? [for (final keyframe in remaining) keyframe.copyWith(time: 0)]
                : remaining;
    final duration = timedRemaining.isEmpty ? 0.0 : timedRemaining.last.time;
    if (!_hasConfiguredAnimationDuration) {
      _animationDurationSeconds = duration;
    }
    final wasSelected = _selectedKeyframeId == id;

    _draft = _draft.copyWith(
      duration: duration,
      keyframes: timedRemaining,
      updatedAt: DateTime.now(),
    );

    if (wasSelected) {
      if (timedRemaining.isEmpty) {
        _selectedKeyframeId = null;
        _playbackTime = 0;
      } else {
        final adjacentIndex = removedIndex.clamp(0, timedRemaining.length - 1);
        final adjacent = timedRemaining[adjacentIndex];
        _selectedKeyframeId = adjacent.id;
        _playbackTime = adjacent.time;
        _loadPose(adjacent.jointRotations);
      }
    } else {
      _playbackTime = _playbackTime.clamp(0, duration).toDouble();
    }
    notifyListeners();
  }

  void playPreview() {
    if (!canPlay || _playbackStatus == CustomExercisePlaybackStatus.playing) {
      return;
    }
    if (_playbackStatus == CustomExercisePlaybackStatus.paused) {
      resumePreview();
      return;
    }
    _playbackStatus = CustomExercisePlaybackStatus.playing;
    _playbackTime = 0;
    notifyListeners();
  }

  void pausePreview() {
    if (_playbackStatus != CustomExercisePlaybackStatus.playing) return;
    _playbackStatus = CustomExercisePlaybackStatus.paused;
    notifyListeners();
  }

  void resumePreview() {
    if (_playbackStatus != CustomExercisePlaybackStatus.paused) return;
    _playbackStatus = CustomExercisePlaybackStatus.playing;
    notifyListeners();
  }

  void stopPreview() {
    if (!_stopPlaybackState()) return;
    notifyListeners();
  }

  void updatePlaybackProgress(double time) {
    if (_playbackStatus == CustomExercisePlaybackStatus.stopped ||
        !time.isFinite) {
      return;
    }
    final safeTime = time.clamp(0, _draft.duration).toDouble();
    if (safeTime == _playbackTime) return;
    _playbackTime = safeTime;
    notifyListeners();
  }

  void completePreview() {
    if (_playbackStatus == CustomExercisePlaybackStatus.stopped) return;
    _playbackStatus = CustomExercisePlaybackStatus.stopped;
    _playbackTime = _draft.duration;
    notifyListeners();
  }

  void updateBasicInfo({required String name, required String description}) {
    if (_draft.name == name && _draft.description == description) return;
    _draft = _draft.copyWith(
      name: name,
      description: description,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  String? get trainingSettingsValidationError => _validateTrainingSettings(
        animationDurationSeconds: _animationDurationSeconds,
        repetitions: _draft.repetitions,
        sets: _draft.sets,
        holdSeconds: _draft.holdSeconds,
      );

  String? updateTrainingSettings({
    required double animationDurationSeconds,
    required int repetitions,
    required int sets,
    required double holdSeconds,
  }) {
    final error = _validateTrainingSettings(
      animationDurationSeconds: animationDurationSeconds,
      repetitions: repetitions,
      sets: sets,
      holdSeconds: holdSeconds,
    );
    if (error != null) return error;
    final keyframes = _draft.keyframes.length >= 2
        ? _scaleKeyframesToDuration(
            _draft.keyframes,
            animationDurationSeconds,
          )
        : _draft.keyframes;
    _animationDurationSeconds = animationDurationSeconds;
    _hasConfiguredAnimationDuration = true;
    _draft = _draft.copyWith(
      repetitions: repetitions,
      sets: sets,
      holdSeconds: holdSeconds,
      duration: keyframes.length >= 2 ? animationDurationSeconds : 0,
      keyframes: keyframes,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    return null;
  }

  String? addPoseMeasurementRule(PoseMeasurementRule rule) {
    final error = _validatePoseMeasurementRule(rule);
    if (error != null) return error;
    _draft = _draft.copyWith(
      poseMeasurementRules: [..._draft.poseMeasurementRules, rule],
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    return null;
  }

  String? updatePoseMeasurementRule(
    int index,
    PoseMeasurementRule rule,
  ) {
    if (index < 0 || index >= _draft.poseMeasurementRules.length) {
      return '找不到要編輯的評估規則';
    }
    final error = _validatePoseMeasurementRule(rule, replacingIndex: index);
    if (error != null) return error;
    final rules = List<PoseMeasurementRule>.of(_draft.poseMeasurementRules);
    rules[index] = rule;
    _draft = _draft.copyWith(
      poseMeasurementRules: rules,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    return null;
  }

  void deletePoseMeasurementRule(int index) {
    if (index < 0 || index >= _draft.poseMeasurementRules.length) return;
    final rules = List<PoseMeasurementRule>.of(_draft.poseMeasurementRules)
      ..removeAt(index);
    _draft = _draft.copyWith(
      poseMeasurementRules: rules,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  String? _validatePoseMeasurementRule(
    PoseMeasurementRule rule, {
    int? replacingIndex,
  }) {
    final error = rule.validationError;
    if (error != null) return error;
    for (var index = 0; index < _draft.poseMeasurementRules.length; index++) {
      if (index != replacingIndex &&
          _draft.poseMeasurementRules[index].measurement == rule.measurement) {
        return '${rule.measurement.poseRuleLabel}已經有一條評估規則';
      }
    }
    return null;
  }

  CustomRehabExercise createSaveSnapshot({DateTime? now}) {
    final validationError = saveValidationError;
    if (validationError != null) {
      throw StateError(validationError);
    }
    return _draft.copyWith(
      name: _draft.name.trim(),
      description: _draft.description.trim(),
      updatedAt: now ?? DateTime.now(),
    );
  }

  void markSaved(CustomRehabExercise savedExercise) {
    if (savedExercise.id != _draft.id) {
      throw ArgumentError('儲存結果的 exercise id 與目前草稿不一致');
    }
    _draft = savedExercise;
    _animationDurationSeconds = savedExercise.duration;
    _hasConfiguredAnimationDuration = true;
    notifyListeners();
  }

  bool _stopPlaybackState() {
    final changed = _playbackStatus != CustomExercisePlaybackStatus.stopped ||
        _playbackTime != 0;
    _playbackStatus = CustomExercisePlaybackStatus.stopped;
    _playbackTime = 0;
    return changed;
  }

  void _loadPose(Map<JointType, JointRotation> source) {
    final pose = _completePose(source);
    for (final joint in CustomExerciseBoneMapping.controllableJoints) {
      _currentPose[joint] = pose[joint]!;
    }
  }

  Map<JointType, JointRotation> _completePose(
    Map<JointType, JointRotation> source,
  ) {
    return {
      for (final joint in CustomExerciseBoneMapping.controllableJoints)
        joint: source[joint] ?? DefaultPose.rotationOf(joint),
    };
  }

  static List<ExerciseKeyframe> _scaleKeyframesToDuration(
    List<ExerciseKeyframe> keyframes,
    double duration,
  ) {
    if (keyframes.length < 2) return List.of(keyframes);
    final sourceEnd = keyframes.last.time;
    if (sourceEnd <= 0) {
      final interval = duration / (keyframes.length - 1);
      return [
        for (var index = 0; index < keyframes.length; index++)
          keyframes[index].copyWith(
            time: index == keyframes.length - 1 ? duration : interval * index,
          ),
      ];
    }
    return [
      for (var index = 0; index < keyframes.length; index++)
        keyframes[index].copyWith(
          time: index == keyframes.length - 1
              ? duration
              : keyframes[index].time / sourceEnd * duration,
        ),
    ];
  }

  static String? _validateTrainingSettings({
    required double animationDurationSeconds,
    required int repetitions,
    required int sets,
    required double holdSeconds,
  }) {
    if (!animationDurationSeconds.isFinite ||
        animationDurationSeconds < 1 ||
        animationDurationSeconds > 60) {
      return '動畫播放時間必須介於 1～60 秒';
    }
    if (repetitions < 1 || repetitions > 100) {
      return '每組次數必須介於 1～100 次';
    }
    if (sets < 1 || sets > 20) {
      return '組數必須介於 1～20 組';
    }
    if (!holdSeconds.isFinite || holdSeconds < 0.5 || holdSeconds > 30) {
      return '保持時間必須介於 0.5～30 秒';
    }
    return null;
  }

  String _createKeyframeId() {
    while (true) {
      final id = 'kf_${_nextKeyframeSequence.toString().padLeft(3, '0')}';
      _nextKeyframeSequence++;
      if (_draft.keyframes.every((item) => item.id != id)) return id;
    }
  }

  static CustomRehabExercise _createDraft({
    required String? therapistId,
    required DateTime now,
  }) {
    return CustomRehabExercise(
      id: 'custom_${now.microsecondsSinceEpoch}',
      name: '',
      description: '',
      createdByTherapistId: therapistId,
      createdAt: now,
      updatedAt: now,
      repetitions: 10,
      sets: 3,
      holdSeconds: 5,
      restSeconds: 30,
      duration: 0,
      keyframes: const [],
      evaluationRules: const [],
    );
  }
}
