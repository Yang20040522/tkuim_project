// lib/screens/training_screen.dart
//
// 只負責：Camera / Overlay UI / Stats 顯示 / Dialog
// 所有動作邏輯（倒數、捏合狀態機）已移至 lib/actions/

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../actions/base_rehab_action.dart';
import '../actions/rehab_action_callback.dart';
import '../actions/side_pinch_action.dart';
import '../actions/turn_palm_action.dart';
import '../models/training_action.dart';
import '../services/mediapipe_service.dart';
import '../widgets/hand_overlay_widget.dart';

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

  // Kotlin 端已翻轉，Flutter overlay 不需再翻
  bool get _overlayMirrored => false;

  // ── 初始化 ───────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // 根據動作類型建立對應 controller
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
      // 側捏不需倒數，直接標記完成讓 trainingStream 可接收
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

      // Landmark stream → 交給 action controller 處理
      _mpService.landmarkStream.listen((result) {
        if (!mounted) return;
        setState(() {
          _landmarks = result.landmarks;
          _handDetected = result.handDetected;
        });
        _action.processLandmarks(result.landmarks);
      });

      // Training stream → 只在 action 準備好時才接收
      _mpService.trainingStream.listen((update) {
        if (!mounted) return;
        if (!_action.isReadyToReceiveUpdates) return;

        setState(() {
          if (update.feedback.isNotEmpty) _feedback = update.feedback;
          if (update.instruction.isNotEmpty) _instruction = update.instruction;
          // 防跳保護：repCount 只允許往上，避免兩個來源打架造成數字倒退
          if (update.repCount > _repCount) _repCount = update.repCount;
          _accuracy = update.accuracy;
          // 側捏的 progress 由 SidePinchAction.processLandmarks 即時計算，不讓 trainingStream 蓋掉
          if (widget.action.type == ActionType.turnPalm) {
            _progress = update.progress;
          }
          _speedState = update.speedState;
          _isComplete = update.isComplete;
        });

        if (update.isComplete) {
          _showCompletionDialog(
            repCount: update.repCount,
            durationSeconds: update.durationSeconds,
            mistakeLogs: update.mistakeLogs,
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

    // 通知翻掌 action 重置倒數（側捏沒有這個方法，用 is 判斷）
    if (_action is TurnPalmAction) {
      (_action as TurnPalmAction).resetForCameraFlip();
    }

    await _mpService.flipCamera();
  }

  void _showCompletionDialog({
    required int repCount,
    required int durationSeconds,
    required List<String> mistakeLogs,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CompletionDialog(
        repCount: repCount,
        durationSeconds: durationSeconds,
        mistakeLogs: mistakeLogs,
        onRetry: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => TrainingScreen(
                action: widget.action,
                difficulty: widget.difficulty,
              ),
            ),
          );
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
    _showCompletionDialog(
      repCount: repCount,
      durationSeconds: durationSeconds,
      mistakeLogs: mistakeLogs,
    );
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            AspectRatio(
              aspectRatio: 3 / 4,
              child: _buildCameraArea(),
            ),
            _buildCoachCard(),
            SlideTransition(
              position: _slideAnim,
              child: _buildStatsPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF161824),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF252738)),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.action.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  widget.difficulty.description,
                  style: const TextStyle(
                      color: Color(0xFF8A8D9F), fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _flipCamera,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF161824),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF252738)),
              ),
              child: const Icon(Icons.flip_camera_ios,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraArea() {
    return Padding(
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
                  hitTestBehavior: PlatformViewHitTestBehavior.opaque,
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
                  params.onPlatformViewCreated,
                );
                controller.addOnPlatformViewCreatedListener((_) {
                  _initMediaPipe();
                });
                controller.create();
                return controller;
              },
            ),
            if (_landmarks.isNotEmpty)
              HandOverlayWidget(
                landmarks: _landmarks,
                isMirrored: _overlayMirrored,
                showStickGuide: _showStickGuide,
                showPinchGuide: _showPinchGuide,
                progress: _progress,
                speedState: _speedState,
              ),
            if (!_isInitialized) _buildLoadingOverlay(),
            if (_isInitialized && !_handDetected && _landmarks.isEmpty)
              _buildNoHandOverlay(),
            if (_isCountingDown && !_countdownDone)
              _buildCountdownOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    return Positioned(
      top: 16,
      right: 16,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(_countdownSeconds),
        tween: Tween(begin: 1.3, end: 1.0),
        duration: const Duration(milliseconds: 350),
        curve: Curves.elasticOut,
        builder: (_, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            shape: BoxShape.circle,
            border: Border.all(
              color: _countdownSeconds <= 2
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFFF9800),
              width: 3,
            ),
          ),
          child: Center(
            child: Text(
              '$_countdownSeconds',
              style: TextStyle(
                color: _countdownSeconds <= 2
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFF9800),
                fontSize: 34,
                fontWeight: FontWeight.w900,
                shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoHandOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.4),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A65FF).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF4A65FF).withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: const Icon(Icons.back_hand_outlined,
                    color: Color(0xFF4A65FF), size: 40),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '請將手放入鏡頭範圍內',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 8, color: Colors.black)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                color: Color(0xFF4A65FF), strokeWidth: 3),
            SizedBox(height: 16),
            Text(
              '正在啟動 AI 引擎...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161824),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF252738)),
      ),
      child: Row(
        children: [
          const Text('🤖', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _feedback,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_instruction.isNotEmpty)
                  Text(
                    _instruction,
                    style: const TextStyle(
                        color: Color(0xFF4A65FF), fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              label: _isCountingDown
                  ? '保持倒數'
                  : (!_countdownDone &&
                          widget.action.type == ActionType.turnPalm
                      ? '準備中'
                      : '完成次數'),
              value: _isCountingDown
                  ? '$_countdownSeconds 秒'
                  : (!_countdownDone &&
                          widget.action.type == ActionType.turnPalm
                      ? '對齊棍子'
                      : '$_repCount / 10'),
              valueColor: _isCountingDown
                  ? (_countdownSeconds <= 2
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF9800))
                  : (!_countdownDone &&
                          widget.action.type == ActionType.turnPalm
                      ? const Color(0xFF8A8D9F)
                      : const Color(0xFF2C3040)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              label: '動作角度',
              value: _accuracy > 0
                  ? '${_accuracy.toStringAsFixed(0)}°'
                  : '--°',
              valueColor: const Color(0xFF4A65FF),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFFF4B4B),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4B4B).withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.stop_rounded,
                  color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF8A8D9F), fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Completion Dialog ────────────────────────────────────────────────────────

class _CompletionDialog extends StatelessWidget {
  final int repCount;
  final int durationSeconds;
  final List<String> mistakeLogs;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  const _CompletionDialog({
    required this.repCount,
    required this.durationSeconds,
    required this.mistakeLogs,
    required this.onRetry,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final perfectCount = 10 - mistakeLogs.length;
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;

    return Dialog(
      backgroundColor: const Color(0xFF161824),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              '訓練完成！',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statItem('完美動作', '$perfectCount / 10',
                    const Color(0xFF4A65FF)),
                _statItem(
                    '花費時間',
                    '$minutes:${seconds.toString().padLeft(2, '0')}',
                    const Color(0xFF4CAF50)),
                _statItem(
                    '失誤次數',
                    '${mistakeLogs.length}',
                    mistakeLogs.isEmpty
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF4B4B)),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A65FF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  '🔄 再來一組',
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
              height: 52,
              child: OutlinedButton(
                onPressed: onHome,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF252738)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  '🏠 回到首頁',
                  style: TextStyle(
                      color: Color(0xFFD0D2E0),
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF8A8D9F), fontSize: 11)),
      ],
    );
  }
}