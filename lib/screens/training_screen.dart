// lib/screens/training_screen.dart
//
// 只負責：Camera / Overlay UI / Stats 顯示 / Dialog
// 所有動作邏輯（倒數、捏合狀態機）已移至 lib/actions/
// UI 元件已拆至 lib/widgets/

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../actions/base_rehab_action.dart';
import '../actions/rehab_action_callback.dart';
import '../actions/side_pinch_action.dart';
import '../actions/turn_palm_action.dart';
import '../models/training_action.dart';
import '../services/mediapipe_service.dart';
import '../services/history_service.dart';

import '../widgets/hand_overlay_widget.dart';
import '../widgets/completion_dialog.dart';
import '../widgets/training_stats_panel.dart';
import '../widgets/training_overlays.dart';

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
    with TickerProviderStateMixin
    implements RehabActionCallback {
  // ── 服務 & 動作 controller ──────────────────────────────────────
  final MediaPipeService _mpService = MediaPipeService();
  late final BaseRehabAction _action;

  // ── UI 狀態 ─────────────────────────────────────────────────────
  List<Landmark> _landmarks = [];
  bool _handDetected = false;
  bool _isFrontCamera = false;
  bool _isInitialized = false;

  String _feedback = '請將手放入鏡頭範圍內';
  String _instruction = '等待偵測中...';
  int _repCount = 0;
  double _accuracy = 0;
  double _progress = 0;
  int _speedState = 0;
  bool _isComplete = false;

  // 倒數（翻掌專用，側捏不會用到）
  int _countdownSeconds = 5;
  bool _isCountingDown = false;
  bool _countdownDone = false;

  // ── 動畫 ────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  bool get _showStickGuide =>
      widget.action.type == ActionType.turnPalm && !_isComplete;
  bool get _showPinchGuide =>
      widget.action.type == ActionType.sidePinch && !_isComplete;
  bool get _overlayMirrored => false;

  // ── 初始化 ───────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final difficultyIndex =
        widget.action.difficulties.indexOf(widget.difficulty) + 1;

    if (widget.action.type == ActionType.turnPalm) {
      _action = TurnPalmAction(
        callback: this,
        overlayMirrored: _overlayMirrored,
      );
    } else {
      _action = SidePinchAction(
        callback: this,
        difficulty: difficultyIndex,
      );
      _countdownDone = true;
    }

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
  }

  Future<void> _initMediaPipe() async {
    try {
      final actionCode = widget.action.type == ActionType.turnPalm
          ? 'TURN_PALM'
          : 'SECOND_ACTION';
      final difficultyIndex =
          widget.action.difficulties.indexOf(widget.difficulty) + 1;

      await _mpService.startDetection(
        actionType: actionCode,
        difficulty: difficultyIndex,
        useFrontCamera: _isFrontCamera,
      );

      _mpService.landmarkStream.listen((result) {
        if (!mounted) return;
        setState(() {
          _landmarks = result.landmarks;
          _handDetected = result.handDetected;
        });
        _action.processLandmarks(result.landmarks);
      });

      _mpService.trainingStream.listen((update) {
        if (!mounted || !_action.isReadyToReceiveUpdates) return;
        setState(() {
          if (update.feedback.isNotEmpty) _feedback = update.feedback;
          if (update.instruction.isNotEmpty) _instruction = update.instruction;
          if (update.repCount > _repCount) _repCount = update.repCount;
          _accuracy = update.accuracy;
          if (widget.action.type == ActionType.turnPalm) {
            _progress = update.progress;
          }
          _speedState = update.speedState;
          _isComplete = update.isComplete;
        });

        if (update.isComplete) {
          _handleCompletion(
            update.repCount,
            update.durationSeconds,
            update.mistakeLogs,
          );
        }
      });

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _feedback = _action.initialFeedback;
          _instruction = _action.initialInstruction;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _feedback = '初始化失敗，請重試');
    }
  }

  Future<void> _flipCamera() async {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _landmarks = [];
      _handDetected = false;
    });
    if (_action is TurnPalmAction) {
      (_action as TurnPalmAction).resetForCameraFlip();
    }
    await _mpService.flipCamera();
  }

  void _handleCompletion(
      int repCount, int durationSeconds, List<String> mistakeLogs) {
    HistoryService().saveRecord(TrainingRecord(
      timestamp: DateTime.now().toString().substring(0, 16),
      actionName: widget.action.name,
      difficulty: widget.action.difficulties.indexOf(widget.difficulty) + 1,
      durationSeconds: durationSeconds,
      mistakeLogs: mistakeLogs,
    ));
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CompletionDialog(
        repCount: repCount,
        durationSeconds: durationSeconds,
        mistakeLogs: mistakeLogs,
        onRetry: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => TrainingScreen(
              action: widget.action,
              difficulty: widget.difficulty,
            ),
          ));
        },
        onHome: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  void dispose() {
    _action.dispose();
    _mpService.stopDetection();
    _mpService.dispose();
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── RehabActionCallback 實作 ─────────────────────────────────────

  @override
  void onFeedbackChanged(String feedback, String instruction) {
    if (!mounted) return;
    setState(() {
      _feedback = feedback;
      _instruction = instruction;
    });
  }

  @override
  void onStatsChanged({
    int? repCount,
    double? accuracy,
    double? progress,
    int? speedState,
  }) {
    if (!mounted) return;
    setState(() {
      if (repCount != null) _repCount = repCount;
      if (accuracy != null) _accuracy = accuracy;
      if (progress != null) _progress = progress;
      if (speedState != null) _speedState = speedState;
    });
  }

  @override
  void onCountdownChanged({
    required bool isCountingDown,
    required int seconds,
    required bool isDone,
  }) {
    if (!mounted) return;
    setState(() {
      _isCountingDown = isCountingDown;
      _countdownSeconds = seconds;
      _countdownDone = isDone;
    });
  }

  @override
  void onTrainingComplete({
    required int repCount,
    required int durationSeconds,
    required List<String> mistakeLogs,
  }) {
    if (!mounted) return;
    setState(() => _isComplete = true);
    _handleCompletion(repCount, durationSeconds, mistakeLogs);
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
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
                      // ── Native Camera（Kotlin / MediaPipe 管理）──
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
                          final controller =
                              PlatformViewsService.initExpensiveAndroidView(
                            id: params.id,
                            viewType: 'com.rehabassist/camera_preview',
                            layoutDirection: TextDirection.ltr,
                            onFocus: () => params.onFocusChanged(true),
                          );
                          controller.addOnPlatformViewCreatedListener(
                              params.onPlatformViewCreated);
                          controller.addOnPlatformViewCreatedListener(
                              (_) => _initMediaPipe());
                          controller.create();
                          return controller;
                        },
                      ),

                      // ── 手部 Overlay ──────────────────────────────
                      if (_landmarks.isNotEmpty)
                        HandOverlayWidget(
                          landmarks: _landmarks,
                          isMirrored: _overlayMirrored,
                          showStickGuide: _showStickGuide,
                          showPinchGuide: _showPinchGuide,
                          progress: _progress,
                          speedState: _speedState,
                        ),

                      // ── 載入 / 無手偵測 / 倒數 Overlay ──────────
                      if (!_isInitialized) const LoadingOverlay(),
                      if (_isInitialized &&
                          !_handDetected &&
                          _landmarks.isEmpty)
                        NoHandOverlay(pulseAnim: _pulseAnim),
                      if (_isCountingDown && !_countdownDone)
                        CountdownOverlay(seconds: _countdownSeconds),
                    ],
                  ),
                ),
              ),
            ),
            CoachCard(feedback: _feedback, instruction: _instruction),
            SlideTransition(
              position: _slideAnim,
              child: TrainingStatsPanel(
                isCountingDown: _isCountingDown,
                countdownDone: _countdownDone,
                countdownSeconds: _countdownSeconds,
                actionType: widget.action.type,
                repCount: _repCount,
                accuracy: _accuracy,
                onStopPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}