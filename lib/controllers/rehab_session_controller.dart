// lib/controllers/rehab_session_controller.dart
//
// 動作判斷邏輯已全部移至 Dart（side_pinch_action / turn_palm_action）
// trainingStream 不再使用，KT 只負責送 landmark
//
// ✅ 新增:pause()/resume(),支援「暫停選單」真正的接續(不重建、不歸零)

import 'dart:async';
import 'package:flutter/material.dart';

import '../actions/base_rehab_action.dart';
import '../actions/rehab_action_callback.dart';
import '../actions/side_pinch_action.dart';
import '../actions/turn_palm_action.dart';
import '../actions/wrist_extension_action.dart';
import '../actions/wrist_side_bend_action.dart';
import '../models/training_action.dart';
import '../services/mediapipe_service.dart';
import '../services/pose_model_interface.dart';

// ── Session 狀態快照 ──────────────────────────────────────────────
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
  final List<String> mistakeLogs;

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
    );
  }
}

// ── Controller ────────────────────────────────────────────────────
class RehabSessionController implements RehabActionCallback {
  final IPoseModel model;
  final TrainingAction action;
  final DifficultyOption difficulty;

  late final BaseRehabAction _actionLogic;

  StreamSubscription? _frameSub;

  final _stateCtrl = StreamController<RehabSessionState>.broadcast();
  Stream<RehabSessionState> get stateStream => _stateCtrl.stream;

  RehabSessionState _state = const RehabSessionState();
  RehabSessionState get currentState => _state;

  // 暫停中:frame 監聽會直接忽略新的一幀,凍結畫面與計次
  bool _isPaused = false;

  RehabSessionController({
    required this.model,
    required this.action,
    required this.difficulty,
  }) {
    final diffIdx = action.difficulties.indexOf(difficulty) + 1;

    switch (action.type) {
      case ActionType.turnPalm:
        _actionLogic = TurnPalmAction(callback: this);

      case ActionType.wristExtension:
        _actionLogic = WristExtensionAction(callback: this);
        // 有 3 秒倒數，countdownDone 由 action 自己透過 onCountdownChanged 設定

      case ActionType.wristSideBend:
        _actionLogic = WristSideBendAction(callback: this);
        // 有 3 秒倒數，countdownDone 由 action 自己透過 onCountdownChanged 設定

      default:
        // sidePinch 及其他手部動作
        _actionLogic = SidePinchAction(callback: this, difficulty: diffIdx);
        _state = _state.copyWith(countdownDone: true);
    }
  }

  // ── 生命週期 ──────────────────────────────────────────────────────

  Future<void> start() async {
    final diffIdx = action.difficulties.indexOf(difficulty) + 1;

    String actionCode = 'SECOND_ACTION';
    if (action.type == ActionType.turnPalm) actionCode = 'TURN_PALM';

    await model.start(PoseModelConfig(
      actionType: actionCode,
      difficulty: diffIdx,
      useFrontCamera: true,
    ));

    // 只訂閱 frameStream，不再訂閱 trainingStream
    _frameSub = model.frameStream.listen((frame) {
      if (_isPaused) return; // 暫停中:忽略這一幀,不更新畫面、不計次

      _emit(_state.copyWith(
        handLandmarks: frame.handLandmarks,
        handDetected: frame.handDetected,
        bodyLandmarks: frame.standardJoints.values.toList(),
      ));

      // 動作判斷全部交給 Dart action
      _actionLogic.processLandmarks(frame.handLandmarks);
    });

    _emit(_state.copyWith(
      feedback: _actionLogic.initialFeedback,
      instruction: _actionLogic.initialInstruction,
    ));
  }

  // ─── 暫停 / 繼續 ─────────────────────────────────────────────────
  // 暫停時相機/原生偵測仍在背景運作,但這裡直接忽略每一幀的結果,
  // 不更新畫面、不餵進動作判斷邏輯,達到「凍結進度」的效果。
  // 繼續時單純把旗標關掉,下一幀開始就會照原本邏輯接續處理,
  // 不需要重新 start()、不會遺失或錯亂目前的 rep 數與狀態。
  void pause() {
    _isPaused = true;
  }

  void resume() {
    _isPaused = false;
  }

  Future<void> flipCamera() async {
    _emit(_state.copyWith(handLandmarks: [], handDetected: false, bodyLandmarks: []));
    if (_actionLogic is TurnPalmAction) {
      (_actionLogic as TurnPalmAction).resetForCameraFlip();
    }
    await model.flipCamera();
  }

  // 等資源真的釋放完才返回,給切換動作時用
  Future<void> disposeAsync() async {
    _actionLogic.dispose();
    await _frameSub?.cancel();

    try {
      await model.stop();
    } catch (_) {
      // 即使原生端拋錯也不要卡住流程,確保一定會往下走
    }

    // 給 Kotlin 端時間完整清理相機 / MediaPipe 資源
    await Future.delayed(const Duration(milliseconds: 350));

    try {
      model.dispose();
    } catch (_) {}

    if (!_stateCtrl.isClosed) await _stateCtrl.close();
  }

  void dispose() {
    _actionLogic.dispose();
    _frameSub?.cancel();
    model.stop();
    model.dispose();
    _stateCtrl.close();
  }

  // ── RehabActionCallback 實作 ──────────────────────────────────────

  @override
  void onFeedbackChanged(String feedback, String instruction) {
    _emit(_state.copyWith(feedback: feedback, instruction: instruction));
  }

  @override
  void onStatsChanged({
    int? repCount,
    double? accuracy,
    double? progress,
    int? speedState,
  }) {
    _emit(_state.copyWith(
      repCount: repCount ?? _state.repCount,
      accuracy: accuracy ?? _state.accuracy,
      progress: progress ?? _state.progress,
      speedState: speedState ?? _state.speedState,
    ));
  }

  @override
  void onCountdownChanged({
    required bool isCountingDown,
    required int seconds,
    required bool isDone,
  }) {
    _emit(_state.copyWith(
      isCountingDown: isCountingDown,
      countdownSeconds: seconds,
      countdownDone: isDone,
    ));
  }

  @override
  void onTrainingComplete({
    required int repCount,
    required int durationSeconds,
    required List<String> mistakeLogs,
  }) {
    _emit(_state.copyWith(
      isComplete: true,
      repCount: repCount,
      durationSeconds: durationSeconds,
      mistakeLogs: mistakeLogs,
    ));
  }

  void _emit(RehabSessionState next) {
    _state = next;
    if (!_stateCtrl.isClosed) _stateCtrl.add(_state);
  }
}