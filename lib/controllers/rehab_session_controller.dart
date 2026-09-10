// lib/controllers/rehab_session_controller.dart
//
// 動作判斷邏輯全部在 Dart Action。
// Kotlin / MediaPipe 只負責 landmarks。
//
// 本版新增：
// 1. 每一幀把 Action.currentMistakeLogs 同步進 state。
// 2. 升到下一難度時清空 state.mistakeLogs。
// 3. 因此 TrainingScreen 原本的 state.mistakeLogs
//    就會自然變成「目前難度自己的錯誤」。

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../actions/base_rehab_action.dart';
import '../actions/rehab_action_callback.dart';
import '../actions/side_pinch_action.dart';
import '../actions/turn_palm_action.dart';
import '../actions/wrist_extension_action.dart';
import '../actions/wrist_side_bend_action.dart';

import '../models/training_action.dart';

import '../services/mediapipe_service.dart';
import '../services/pi_pose_model.dart';
import '../services/pose_model_interface.dart';

class RehabSessionState {
  final List<Landmark> handLandmarks;
  final bool handDetected;

  final List<Offset> bodyLandmarks;

  final String feedback;
  final String instruction;

  final int repCount;

  final double accuracy;
  final double progress;

  final int speedState;

  final bool isComplete;

  final bool isCountingDown;
  final int countdownSeconds;
  final bool countdownDone;

  final int durationSeconds;

  /// 只代表「目前這一階」的錯誤。
  final List<String> mistakeLogs;

  final int targetReps;

  final String currentLevelLabel;
  final int currentLevel;

  final bool pendingLevelUp;
  final int pendingNextLevel;
  final String pendingNextLevelLabel;

  final Uint8List? imageBytes;

  const RehabSessionState({
    this.handLandmarks = const [],
    this.handDetected = false,
    this.bodyLandmarks = const [],
    this.feedback = '請將手放入鏡頭範圍內',
    this.instruction = '等待偵測中...',
    this.repCount = 0,
    this.accuracy = 0,
    this.progress = 0,
    this.speedState = 0,
    this.isComplete = false,
    this.isCountingDown = false,
    this.countdownSeconds = 5,
    this.countdownDone = false,
    this.durationSeconds = 0,
    this.mistakeLogs = const [],
    this.targetReps = 10,
    this.imageBytes,
    this.currentLevelLabel = '',
    this.currentLevel = 1,
    this.pendingLevelUp = false,
    this.pendingNextLevel = 1,
    this.pendingNextLevelLabel = '',
  });

  RehabSessionState copyWith({
    List<Landmark>? handLandmarks,
    bool? handDetected,
    List<Offset>? bodyLandmarks,
    String? feedback,
    String? instruction,
    int? repCount,
    double? accuracy,
    double? progress,
    int? speedState,
    bool? isComplete,
    bool? isCountingDown,
    int? countdownSeconds,
    bool? countdownDone,
    int? durationSeconds,
    List<String>? mistakeLogs,
    int? targetReps,
    Uint8List? imageBytes,
    String? currentLevelLabel,
    int? currentLevel,
    bool? pendingLevelUp,
    int? pendingNextLevel,
    String? pendingNextLevelLabel,
  }) {
    return RehabSessionState(
      handLandmarks: handLandmarks ?? this.handLandmarks,
      handDetected: handDetected ?? this.handDetected,
      bodyLandmarks: bodyLandmarks ?? this.bodyLandmarks,
      feedback: feedback ?? this.feedback,
      instruction: instruction ?? this.instruction,
      repCount: repCount ?? this.repCount,
      accuracy: accuracy ?? this.accuracy,
      progress: progress ?? this.progress,
      speedState: speedState ?? this.speedState,
      isComplete: isComplete ?? this.isComplete,
      isCountingDown: isCountingDown ?? this.isCountingDown,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      countdownDone: countdownDone ?? this.countdownDone,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      mistakeLogs: mistakeLogs ?? this.mistakeLogs,
      targetReps: targetReps ?? this.targetReps,
      imageBytes: imageBytes ?? this.imageBytes,
      currentLevelLabel: currentLevelLabel ?? this.currentLevelLabel,
      currentLevel: currentLevel ?? this.currentLevel,
      pendingLevelUp: pendingLevelUp ?? this.pendingLevelUp,
      pendingNextLevel: pendingNextLevel ?? this.pendingNextLevel,
      pendingNextLevelLabel:
          pendingNextLevelLabel ?? this.pendingNextLevelLabel,
    );
  }
}

class RehabSessionController implements RehabActionCallback {
  final IPoseModel model;

  final TrainingAction action;

  final DifficultyOption difficulty;

  BaseRehabAction? _actionLogic;

  StreamSubscription? _frameSub;

  final _stateCtrl = StreamController<RehabSessionState>.broadcast();

  Stream<RehabSessionState> get stateStream => _stateCtrl.stream;

  RehabSessionState _state = const RehabSessionState();

  RehabSessionState get currentState => _state;

  IPoseModel get currentModel => model;

  /// 目前這一階 Action 真正保存的錯誤。
  ///
  /// 某些 Action 在 constructor 裡就會立刻透過 callback 回呼
  /// onLevelUp / onFeedbackChanged。那個時間點 `_actionLogic`
  /// 可能還沒完成指派，所以這裡必須容許 null。
  List<String> get currentMistakeLogs => _safeCurrentMistakeLogs();

  List<String> _safeCurrentMistakeLogs() => List<String>.from(
        _actionLogic?.currentMistakeLogs ?? _state.mistakeLogs,
      );

  bool _isPaused = false;

  RehabSessionController({
    required this.model,
    required this.action,
    required this.difficulty,
  }) {
    final diffIdx = action.difficulties.indexWhere(
          (d) => d.level == difficulty.level,
        ) +
        1;

    _state = _state.copyWith(
      targetReps: difficulty.targetReps,
      currentLevel: diffIdx,
    );

    final bool isExternalSource = model is PiPoseModel;

    switch (action.type) {
      case ActionType.turnPalm:
        _actionLogic = TurnPalmAction(
          callback: this,
          startingLevel: diffIdx,
          targetReps: difficulty.targetReps,
          overlayMirrored: isExternalSource,
        );
        break;

      case ActionType.wristExtension:
        _actionLogic = WristExtensionAction(
          callback: this,
          targetReps: difficulty.targetReps,
        );
        break;

      case ActionType.wristSideBend:
        _actionLogic = WristSideBendAction(
          callback: this,
          targetReps: difficulty.targetReps,
        );
        break;

      case ActionType.sidePinch:
        _actionLogic = SidePinchAction(
          callback: this,
          difficulty: diffIdx,
          targetReps: difficulty.targetReps,
        );
        break;

      default:
        _actionLogic = SidePinchAction(
          callback: this,
          difficulty: diffIdx,
          targetReps: difficulty.targetReps,
        );

        _state = _state.copyWith(
          countdownDone: true,
        );
        break;
    }
  }

  Future<void> start() async {
    final diffIdx = action.difficulties.indexWhere(
          (d) => d.level == difficulty.level,
        ) +
        1;

    String actionCode = 'SECOND_ACTION';

    if (action.type == ActionType.turnPalm) {
      actionCode = 'TURN_PALM';
    }

    await model.start(
      PoseModelConfig(
        actionType: actionCode,
        difficulty: diffIdx,
        useFrontCamera: true,
      ),
    );

    _frameSub = model.frameStream.listen(
      (frame) {
        if (_isPaused) return;

        _emit(
          _state.copyWith(
            handLandmarks: frame.handLandmarks,
            handDetected: frame.handDetected,
            bodyLandmarks: frame.standardJoints.values.toList(),
            imageBytes: frame.imageBytes,
          ),
        );

        /// Action 先處理這一幀。
        _actionLogic?.processLandmarks(
          frame.handLandmarks,
        );

        /// 關鍵：
        /// 每一幀處理完後，把目前這一階 Action
        /// 的 mistakeLogs 同步到 SessionState。
        ///
        /// 所以升級前 TrainingScreen 原本的：
        ///
        /// state.mistakeLogs
        ///
        /// 就會是該難度自己的錯誤。
        _emit(
          _state.copyWith(
            mistakeLogs: _safeCurrentMistakeLogs(),
          ),
        );
      },
    );

    _emit(
      _state.copyWith(
        feedback: _actionLogic?.initialFeedback ?? _state.feedback,
        instruction: _actionLogic?.initialInstruction ?? _state.instruction,
        mistakeLogs: _safeCurrentMistakeLogs(),
      ),
    );
  }

  void pause() {
    _isPaused = true;
  }

  void resume() {
    _isPaused = false;
  }

  void confirmLevelUp({
    int? customTargetReps,
  }) {
    // _actionLogic 目前允許為 null，因為某些 Action 在 constructor
    // 尚未完成指派前就可能先 callback。
    //
    // 這裡明確轉成 nullable 的 LevelUpControllable，
    // 再使用 ?. 呼叫，避免 analyzer 的 nullable receiver 錯誤。
    final LevelUpControllable? controllable =
        _actionLogic is LevelUpControllable
            ? _actionLogic as LevelUpControllable
            : null;

    controllable?.confirmLevelUp(
      customTargetReps: customTargetReps,
    );

    _emit(
      _state.copyWith(
        pendingLevelUp: false,

        /// 進入下一階後，畫面端的錯誤紀錄重新開始。
        mistakeLogs: const <String>[],
      ),
    );
  }

  void declineLevelUp() {
    final LevelUpControllable? controllable =
        _actionLogic is LevelUpControllable
            ? _actionLogic as LevelUpControllable
            : null;

    controllable?.declineLevelUp();

    _emit(
      _state.copyWith(
        pendingLevelUp: false,
      ),
    );
  }

  Future<void> flipCamera() async {
    _emit(
      _state.copyWith(
        handLandmarks: const [],
        handDetected: false,
        bodyLandmarks: const [],
      ),
    );

    final logic = _actionLogic;

    if (logic is TurnPalmAction) {
      logic.resetForCameraFlip();
    }

    await model.flipCamera();
  }

  Future<void> disposeAsync() async {
    _actionLogic?.dispose();

    await _frameSub?.cancel();

    try {
      await model.stop();
    } catch (_) {}

    await Future.delayed(
      const Duration(
        milliseconds: 350,
      ),
    );

    try {
      model.dispose();
    } catch (_) {}

    if (!_stateCtrl.isClosed) {
      await _stateCtrl.close();
    }
  }

  void dispose() {
    _actionLogic?.dispose();

    _frameSub?.cancel();

    model.stop();

    model.dispose();

    if (!_stateCtrl.isClosed) {
      _stateCtrl.close();
    }
  }

  @override
  void onFeedbackChanged(
    String feedback,
    String instruction,
  ) {
    _emit(
      _state.copyWith(
        feedback: feedback,
        instruction: instruction,

        /// 同步目前難度錯誤。
        mistakeLogs: _safeCurrentMistakeLogs(),
      ),
    );
  }

  @override
  void onStatsChanged({
    int? repCount,
    double? accuracy,
    double? progress,
    int? speedState,
  }) {
    _emit(
      _state.copyWith(
        repCount: repCount ?? _state.repCount,
        accuracy: accuracy ?? _state.accuracy,
        progress: progress ?? _state.progress,
        speedState: speedState ?? _state.speedState,
        mistakeLogs: _safeCurrentMistakeLogs(),
      ),
    );
  }

  @override
  void onCountdownChanged({
    required bool isCountingDown,
    required int seconds,
    required bool isDone,
  }) {
    _emit(
      _state.copyWith(
        isCountingDown: isCountingDown,
        countdownSeconds: seconds,
        countdownDone: isDone,
      ),
    );
  }

  @override
  void onLevelUp({
    required int newLevel,
    required String levelLabel,
    required int newTargetReps,
  }) {
    _emit(
      _state.copyWith(
        currentLevelLabel: levelLabel,
        currentLevel: newLevel,
        targetReps: newTargetReps,

        /// 新難度全部重新計算。
        repCount: 0,

        /// 關鍵：
        /// 不要把上一階的錯誤帶進下一階。
        mistakeLogs: const <String>[],
      ),
    );
  }

  @override
  void onLevelUpReady({
    required int nextLevel,
    required String nextLevelLabel,
  }) {
    /// 此時還沒真正升級，
    /// 所以保留目前難度的 mistakeLogs。
    _emit(
      _state.copyWith(
        pendingLevelUp: true,
        pendingNextLevel: nextLevel,
        pendingNextLevelLabel: nextLevelLabel,
        mistakeLogs: _safeCurrentMistakeLogs(),
      ),
    );
  }

  @override
  void onTrainingComplete({
    required int repCount,
    required int durationSeconds,
    required List<String> mistakeLogs,
  }) {
    _emit(
      _state.copyWith(
        isComplete: true,
        repCount: repCount,
        durationSeconds: durationSeconds,

        /// 完成時 Action 傳進來的就是目前這一階。
        mistakeLogs: List<String>.from(
          mistakeLogs,
        ),
      ),
    );
  }

  void _emit(
    RehabSessionState next,
  ) {
    _state = next;

    if (!_stateCtrl.isClosed) {
      _stateCtrl.add(_state);
    }
  }
}
