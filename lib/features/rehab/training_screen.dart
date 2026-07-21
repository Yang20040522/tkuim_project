// lib/screens/training_screen.dart
//
// ══════════════════════════════════════════════════════════════════
//  重構後的主控畫面
//
//  改動：CompletionDialog 加入 onStartNew callback，
//        支援完成後直接選其他動作或切換難度。
//  ✅ 訓練開始/結束自動錄影,結束時詢問是否保留
//  ✅ 新增:按下停止鍵先跳「暫停選單」(繼續 / 結束),
//     選「繼續」時呼叫 controller.resume(),完全接續原本的次數與狀態;
//     只有選「結束」才會進入原本的完整結束流程(停止錄影、存紀錄、跳完成畫面)。
// ══════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../controllers/rehab_session_controller.dart';
import '../../models/training_action.dart';
import '../../services/history_service.dart';
import '../../services/mediapipe_model.dart';
import '../../services/screen_recorder_service.dart';

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

enum _PauseChoice { resume, end }

class _TrainingScreenState extends State<TrainingScreen>
    with TickerProviderStateMixin {

  late final RehabSessionController _controller;

  bool _isInitialized = false;
  bool _completionShown = false;

  // 是否正暫停中(暫停選單開啟期間為 true)
  bool _isPaused = false;

  // 停止錄影後、使用者尚未決定去留前的暫存路徑
  String? _pendingVideoPath;

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

  // ── 切換畫面用:不做轉場動畫 ───────────────────────────────────
  void _pushReplacementNoAnimation(Widget screen) {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => screen,
    ));
  }

  Future<void> _onPlatformViewCreated() async {
    await _controller.start();
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() => _isInitialized = true);

    // 錄影是附加功能,失敗不應影響訓練本身
    ScreenRecorderService.startRecording();
  }

  @override
  void dispose() {
    // 保險:如果畫面被意外關掉而沒有走到完整結束流程,錄影可能還在跑,
    // 這裡補一次停止並直接刪除暫存檔(視為不保留)。
    if (!_completionShown) {
      ScreenRecorderService.stopRecording().then((path) {
        if (path != null) {
          File(path).delete().catchError((e) => File(path));
        }
      });
    }
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
    _pendingVideoPath = await ScreenRecorderService.stopRecording();

    final result = await showDialog<_CompletionResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => CompletionDialog(
        repCount: state.repCount,
        durationSeconds: state.durationSeconds,
        mistakeLogs: state.mistakeLogs,
        currentAction: widget.action,
        currentDifficulty: widget.difficulty,
        hasVideo: _pendingVideoPath != null,
        onVideoDecision: _handleVideoDecision,
        onRetry: () =>
            Navigator.of(dialogCtx).pop(_CompletionResult.retry()),
        onHome: () =>
            Navigator.of(dialogCtx).pop(_CompletionResult.home()),
        onStartNew: (a, d) =>
            Navigator.of(dialogCtx).pop(_CompletionResult.startNew(a, d)),
      ),
    );

    // 儲存紀錄(此時 _pendingVideoPath 已經依照使用者的保留/不保留決定更新過)
    HistoryService().saveRecord(TrainingRecord(
      timestamp: DateTime.now().toString().substring(0, 16),
      actionName: widget.action.name,
      //difficulty: widget.action.difficulties.indexOf(widget.difficulty) + 1,
      difficulty: widget.action.difficulties.indexWhere((d) => d.level == widget.difficulty.level) + 1,
      durationSeconds: state.durationSeconds,
      mistakeLogs: state.mistakeLogs,
      videoPath: _pendingVideoPath,
      targetReps: widget.difficulty.targetReps, // ✅ 新增這行，兩處都加
    ));

    if (!mounted || result == null) return;

    switch (result.kind) {
      case _CompletionKind.retry:
        _pushReplacementNoAnimation(TrainingScreen(
          action: widget.action,
          difficulty: widget.difficulty,
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

  // ─── 按停止鍵觸發:先跳「暫停選單」,不動任何狀態或錄影 ─────────
  Future<void> _handleStopButtonTap() async {
    if (_completionShown || !_isInitialized || _isPaused) return;

    setState(() => _isPaused = true);
    _controller.pause();

    final choice = await showDialog<_PauseChoice>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _PauseMenuDialog(
        onResume: () => Navigator.of(dialogCtx).pop(_PauseChoice.resume),
        onEnd: () => Navigator.of(dialogCtx).pop(_PauseChoice.end),
      ),
    );

    if (!mounted) return;

    if (choice != _PauseChoice.end) {
      // 選「繼續」,或用其他方式關掉選單(一律視為繼續)
      _controller.resume();
      setState(() => _isPaused = false);
      return;
    }

    // 選「結束」→ 進入原本的完整結束流程
    await _handleRealEnd();
  }

  // ─── 真正的結束流程(停止錄影、存紀錄、跳完成 dialog)─────
  Future<void> _handleRealEnd() async {
    _completionShown = true;

    final state = _controller.currentState;
    _pendingVideoPath = await ScreenRecorderService.stopRecording();

    final result = await showDialog<_CompletionResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => CompletionDialog(
        isPaused: false,
        repCount: state.repCount,
        durationSeconds: state.durationSeconds,
        mistakeLogs: state.mistakeLogs,
        currentAction: widget.action,
        currentDifficulty: widget.difficulty,
        hasVideo: _pendingVideoPath != null,
        onVideoDecision: _handleVideoDecision,
        onRetry: () =>
            Navigator.of(dialogCtx).pop(_CompletionResult.retry()),
        onHome: () =>
            Navigator.of(dialogCtx).pop(_CompletionResult.home()),
        onStartNew: (a, d) =>
            Navigator.of(dialogCtx).pop(_CompletionResult.startNew(a, d)),
      ),
    );

    HistoryService().saveRecord(TrainingRecord(
      timestamp: DateTime.now().toString().substring(0, 16),
      actionName: widget.action.name,
      //difficulty: widget.action.difficulties.indexOf(widget.difficulty) + 1,
      difficulty: widget.action.difficulties.indexWhere((d) => d.level == widget.difficulty.level) + 1,
      durationSeconds: state.durationSeconds,
      mistakeLogs: state.mistakeLogs,
      videoPath: _pendingVideoPath,
      targetReps: widget.difficulty.targetReps, // ✅ 新增這行，兩處都加
    ));

    if (!mounted || result == null) return;

    switch (result.kind) {
      case _CompletionKind.retry:
        _pushReplacementNoAnimation(TrainingScreen(
          action: widget.action,
          difficulty: widget.difficulty,
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

  // dialog 裡使用者選「保留/不保留」時呼叫;不保留就把暫存檔刪掉
  void _handleVideoDecision(bool keep) {
    if (!keep && _pendingVideoPath != null) {
      final path = _pendingVideoPath!;
      _pendingVideoPath = null;
      File(path).delete().catchError((e) => File(path));
    }
  }

  /// 根據動作類型導航到對應畫面
  Future<void> _navigateToAction(TrainingAction action, DifficultyOption difficulty) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    await _controller.disposeAsync();
    if (!mounted) return;
    
    Widget screen;
    final diff = _mapDifficulty(difficulty.level);
    switch (action.type) {
      case ActionType.wipeBody:
        screen = BodyTrainingScreen(
          action: StandingKneeRaiseAction(difficulty: diff),
          trainingActionMeta: action,
          difficultyMeta: difficulty,
        );
      case ActionType.drawCircle:
        screen = BodyTrainingScreen(
          action: DrawCircleAction(difficulty: diff),
          trainingActionMeta: action,
          difficultyMeta: difficulty,
        );
      case ActionType.reach:
        screen = BodyTrainingScreen(
          action: ReachAction(difficulty: diff),
          trainingActionMeta: action,
          difficultyMeta: difficulty,
        );
      case ActionType.raiseBothArms:
        screen = BodyTrainingScreen(
          action: RaiseBothArmsAction(difficulty: diff),
          trainingActionMeta: action,
          difficultyMeta: difficulty,
        );
      case ActionType.elbowForward:
        screen = BodyTrainingScreen(
          action: ElbowForwardAction(difficulty: diff),
          trainingActionMeta: action,
          difficultyMeta: difficulty,
        );
      default:
        screen = TrainingScreen(action: action, difficulty: difficulty);
    }
    
    if (!mounted) return;
    _pushReplacementNoAnimation(screen);
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
              //difficultyDesc: widget.difficulty.description,
              difficultyDesc: s.currentLevelLabel.isNotEmpty
                  ? s.currentLevelLabel              // ✅ 有更新過就用新的
                  : widget.difficulty.description,   // 保底:剛開始還沒收到更新前,先顯示原本選的
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
                      if (_isPaused)
                        Container(
                          color: Colors.black.withOpacity(0.4),
                          child: const Center(
                            child: Text(
                              '⏸ 已暫停',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                              ),
                            ),
                          ),
                        ),
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
                targetReps: s.targetReps,   // ← 新增
                accuracy: s.accuracy,
                onStopPressed: _handleStopButtonTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 暫停選單 dialog:只有「繼續」跟「結束」兩個選項 ──────────────
class _PauseMenuDialog extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onEnd;

  const _PauseMenuDialog({
    required this.onResume,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⏸️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 10),
            const Text(
              '訓練已暫停',
              style: TextStyle(
                color: Color(0xFF1A1D2E),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '要接續剛剛的訓練,還是結束呢?',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onResume,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A65FF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  '▶️ 繼續訓練',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: onEnd,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFDDE0F0)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  '結束訓練',
                  style: TextStyle(
                      color: Color(0xFFFF4B4B),
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
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