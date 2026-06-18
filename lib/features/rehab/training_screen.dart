// lib/screens/training_screen.dart
//
// ══════════════════════════════════════════════════════════════════
//  重構後的主控畫面
//
//  改動：CompletionDialog 加入 onStartNew callback，
//        支援完成後直接選其他動作或切換難度。
// ══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../controllers/rehab_session_controller.dart';
import '../../models/training_action.dart';
import '../../services/history_service.dart';
import '../../services/mediapipe_model.dart';

import '../../widgets/hand_overlay_widget.dart';
import '../../widgets/completion_dialog.dart';
import '../../widgets/training_stats_panel.dart';
import '../../widgets/training_overlays.dart';
import '../../services/pose_model_interface.dart';

import 'body_training_screen.dart';
import '../../actions/standing_knee_raise_action.dart';
import '../../actions/draw_circle_action.dart';
import '../../actions/reach_action.dart';
import '../../actions/raise_both_arms_action.dart';
import '../../actions/elbow_forward_action.dart';

import '../../actions/body_rehab_action.dart';



class TrainingScreen extends StatefulWidget {
  final TrainingAction action;
  final DifficultyOption difficulty;

  const TrainingScreen({
    super.key,
    required this.action,
    required this.difficulty,
  });

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen>
    with TickerProviderStateMixin {

  late final RehabSessionController _controller;

  bool _isInitialized = false;
  bool _completionShown = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  bool get _showStickGuide => widget.action.type == ActionType.turnPalm;
  bool get _showPinchGuide => widget.action.type == ActionType.sidePinch;

  @override
  void initState() {
    super.initState();

    final IPoseModel selectedModel = MediaPipeModel();
    _controller = RehabSessionController(
      model: selectedModel,
      action: widget.action,
      difficulty: widget.difficulty,
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));

    _controller.stateStream.listen((state) {
      if (!mounted) return;
      setState(() {});
      if (state.isComplete && !_completionShown) {
        _completionShown = true;
        _handleCompletion(state);
      }
    });
  }

  Future<void> _onPlatformViewCreated() async {
    await _controller.start();
    if (mounted) setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _flipCamera() async {
    await _controller.flipCamera();
    if (mounted) setState(() {});
  }

  Future<void> _handleCompletion(RehabSessionState state) async {
    // 儲存紀錄
    HistoryService().saveRecord(TrainingRecord(
      timestamp: DateTime.now().toString().substring(0, 16),
      actionName: widget.action.name,
      difficulty: widget.action.difficulties.indexOf(widget.difficulty) + 1,
      durationSeconds: state.durationSeconds,
      mistakeLogs: state.mistakeLogs,
    ));

    // dialog 不直接導航,而是回傳「使用者選了什麼」
    final result = await showDialog<_CompletionResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => CompletionDialog(
        repCount: state.repCount,
        durationSeconds: state.durationSeconds,
        mistakeLogs: state.mistakeLogs,
        currentAction: widget.action,
        currentDifficulty: widget.difficulty,
        onRetry: () =>
            Navigator.of(dialogCtx).pop(_CompletionResult.retry()),
        onHome: () =>
            Navigator.of(dialogCtx).pop(_CompletionResult.home()),
        onStartNew: (a, d) =>
            Navigator.of(dialogCtx).pop(_CompletionResult.startNew(a, d)),
      ),
    );

    if (!mounted || result == null) return;

    // dialog 已關閉,Navigator 空閒,現在跳安全
    switch (result.kind) {
      case _CompletionKind.retry:
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => TrainingScreen(
            action: widget.action,
            difficulty: widget.difficulty,
          ),
        ));
        break;
      case _CompletionKind.home:
        Navigator.of(context).pop();
        break;
      case _CompletionKind.startNew:
        _navigateToAction(result.action!, result.difficulty!);
        break;
    }
  }

  /// 根據動作類型導航到對應畫面
  /// - 全身動作 → BodyTrainingScreen
  /// - 手部動作（包含新的 wristExtension / wristSideBend）→ TrainingScreen
  void _navigateToAction(TrainingAction action, DifficultyOption difficulty) {
    Widget screen;

    switch (action.type) {
      case ActionType.wipeBody:
        screen = BodyTrainingScreen(
            action: StandingKneeRaiseAction(difficulty: _mapDifficulty(difficulty.level)));

      case ActionType.drawCircle:
        screen = BodyTrainingScreen(
            action: DrawCircleAction(difficulty: _mapDifficulty(difficulty.level)));

      case ActionType.reach:
        screen = BodyTrainingScreen(
            action: ReachAction(difficulty: _mapDifficulty(difficulty.level)));

      case ActionType.raiseBothArms:
        screen = BodyTrainingScreen(action: RaiseBothArmsAction());

      case ActionType.elbowForward:
        screen = BodyTrainingScreen(action: ElbowForwardAction());

      default:
        // 所有手部動作（turnPalm, sidePinch, wristExtension, wristSideBend）
        screen = TrainingScreen(action: action, difficulty: difficulty);
    }

    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => screen));
  }

  RehabDifficulty _mapDifficulty(DifficultyLevel level) {
    switch (level) {
      case DifficultyLevel.level1:
        return RehabDifficulty.easy;
      case DifficultyLevel.level2:
        return RehabDifficulty.medium;
      case DifficultyLevel.level3:
        return RehabDifficulty.hard;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _controller.currentState;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(
          children: [
            TrainingTopBar(
              actionName: widget.action.name,
              difficultyDesc: widget.difficulty.description,
              onBack: () => Navigator.of(context).pop(),
              onFlipCamera: _flipCamera,
            ),
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PlatformViewLink(
                        viewType: 'com.rehabassist/camera_preview',
                        surfaceFactory: (context, controller) {
                          return AndroidViewSurface(
                            controller: controller as AndroidViewController,
                            gestureRecognizers: const {},
                            hitTestBehavior:
                                PlatformViewHitTestBehavior.opaque,
                          );
                        },
                        onCreatePlatformView: (params) {
                          final ctrl =
                              PlatformViewsService.initExpensiveAndroidView(
                            id: params.id,
                            viewType: 'com.rehabassist/camera_preview',
                            layoutDirection: TextDirection.ltr,
                            onFocus: () => params.onFocusChanged(true),
                          );
                          ctrl.addOnPlatformViewCreatedListener(
                              params.onPlatformViewCreated);
                          ctrl.addOnPlatformViewCreatedListener(
                              (_) => _onPlatformViewCreated());
                          ctrl.create();
                          return ctrl;
                        },
                      ),
                      if (s.handLandmarks.isNotEmpty)
                        HandOverlayWidget(
                          landmarks: s.handLandmarks,
                          isMirrored: false,
                          showStickGuide: _showStickGuide && !s.isComplete,
                          showPinchGuide: _showPinchGuide && !s.isComplete,
                          progress: s.progress,
                          speedState: s.speedState,
                        ),
                      if (!_isInitialized) const LoadingOverlay(),
                      if (_isInitialized &&
                          !s.handDetected &&
                          s.handLandmarks.isEmpty)
                        NoHandOverlay(pulseAnim: _pulseAnim),
                      if (s.isCountingDown && !s.countdownDone)
                        CountdownOverlay(seconds: s.countdownSeconds),
                    ],
                  ),
                ),
              ),
            ),
            CoachCard(
              feedback: s.feedback,
              instruction: s.instruction,
            ),
            SlideTransition(
              position: _slideAnim,
              child: TrainingStatsPanel(
                isCountingDown: s.isCountingDown,
                countdownDone: s.countdownDone,
                countdownSeconds: s.countdownSeconds,
                actionType: widget.action.type,
                repCount: s.repCount,
                accuracy: s.accuracy,
                onStopPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CompletionKind { retry, home, startNew }

class _CompletionResult {
  final _CompletionKind kind;
  final TrainingAction? action;
  final DifficultyOption? difficulty;
  const _CompletionResult._(this.kind, this.action, this.difficulty);
  factory _CompletionResult.retry() =>
      const _CompletionResult._(_CompletionKind.retry, null, null);
  factory _CompletionResult.home() =>
      const _CompletionResult._(_CompletionKind.home, null, null);
  factory _CompletionResult.startNew(
          TrainingAction a, DifficultyOption d) =>
      _CompletionResult._(_CompletionKind.startNew, a, d);
}