// lib/controllers/rehab_session_controller.dart
//
// 動作判斷邏輯已全部移至 Dart（side_pinch_action / turn_palm_action）
// trainingStream 不再使用，KT 只負責送 landmark

import 'dart:async';
import 'package:flutter/material.dart';

import '../actions/base_rehab_action.dart';
import '../actions/rehab_action_callback.dart';
import '../actions/side_pinch_action.dart';
import '../actions/turn_palm_action.dart';
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

  RehabSessionController({
    required this.model,
    required this.action,
    required this.difficulty,
  }) {
    final diffIdx = action.difficulties.indexOf(difficulty) + 1;

    if (action.type == ActionType.turnPalm) {
      _actionLogic = TurnPalmAction(callback: this);
    } else {
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

  Future<void> flipCamera() async {
    _emit(_state.copyWith(handLandmarks: [], handDetected: false, bodyLandmarks: []));
    if (_actionLogic is TurnPalmAction) {
      (_actionLogic as TurnPalmAction).resetForCameraFlip();
    }
    await model.flipCamera();
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