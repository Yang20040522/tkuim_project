// lib/features/rehab/body_training_screen.dart
//
// ══════════════════════════════════════════════════════════════════
//  全身復健「共用畫面殼」
//  🚀 支援切換鏡頭來源(手機內建 / 樹莓派外接)
//  🚀 樹莓派模式下,手部骨架改走樹莓派偵測(PiHandSource),
//     與身體骨架共用同一套座標映射方式,確保兩者貼合對齊
// ══════════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:typed_data'; // 用到 Uint8List
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../models/pose_data.dart';
import '../../models/body_frame.dart';
import '../../models/training_action.dart';
import '../../services/body_pose_engine.dart';
import '../../services/history_service.dart';
import '../../services/screen_recorder_service.dart';
import '../../services/pi_camera_source.dart'; // 🚀 樹莓派新增
import '../../services/pi_hand_source.dart'; // 🚀 樹莓派手部新增
import '../../services/mediapipe_service.dart'; // 🚀 樹莓派手部新增(Landmark/DetectionResult/MediaPipeService)
import '../../widgets/pi_ip_dialog.dart'; // 🚀 樹莓派新增
import '../../actions/body_rehab_action.dart';
import '../../actions/standing_knee_raise_action.dart';
import '../../actions/draw_circle_action.dart';
import '../../actions/reach_action.dart';
import '../../widgets/completion_dialog.dart';
import 'training_screen.dart';

import '../../services/voice_service.dart';
import '../../actions/raise_both_arms_action.dart';
import '../../actions/elbow_forward_action.dart';
import '../../actions/sit_to_stand_action.dart';
import '../../actions/lateral_step_action.dart';

// 達標下限:當前難度做 ≥ 3 下,按結束才會存紀錄
const int _kMinRepsToSave = 3;

// RTMPose 133 點 → RehabJoint 對應表
const Map<RehabJoint, int> _kJointIndex = {
  RehabJoint.leftShoulder: 5,
  RehabJoint.rightShoulder: 6,
  RehabJoint.leftElbow: 7,
  RehabJoint.rightElbow: 8,
  RehabJoint.leftWrist: 9,
  RehabJoint.rightWrist: 10,
  RehabJoint.leftHip: 11,
  RehabJoint.rightHip: 12,
  RehabJoint.leftKnee: 13,
  RehabJoint.rightKnee: 14,
  RehabJoint.leftAnkle: 15,
  RehabJoint.rightAnkle: 16,
};

const _skeletonConnections = [
  [0, 1], [0, 2], [1, 3], [2, 4],
  [5, 6], [5, 7], [7, 9], [6, 8], [8, 10],
  [5, 11], [6, 12], [11, 12],
  [11, 13], [13, 15], [12, 14], [14, 16],
];

class BodyTrainingScreen extends StatefulWidget {
  final BodyRehabAction action;

  final TrainingAction? trainingActionMeta;
  final DifficultyOption? difficultyMeta;

  const BodyTrainingScreen({
    super.key,
    required this.action,
    this.trainingActionMeta,
    this.difficultyMeta,
  });

  @override
  State<BodyTrainingScreen> createState() => _BodyTrainingScreenState();
}

enum _PauseChoice { resume, end }

class _BodyTrainingScreenState extends State<BodyTrainingScreen> {
  final BodyPoseEngine _engine = BodyPoseEngine();
  static const double _scoreThreshold = BodyPoseEngine.scoreThreshold;

  // 🚀 樹莓派新增:外接鏡頭來源(null = 尚未連線)
  PiCameraSource? _piCamera;
  bool _isExternalCamera = false;
  String? _lastPiIp;

  // 🚀 樹莓派手部偵測新增:另開一條連線拿手部 landmarks
  final MediaPipeService _handService = MediaPipeService();
  PiHandSource? _piHand;

  int _repCount = 0;
  String _feedback = '請將身體放入鏡頭範圍內';
  late String _instruction;
  bool _bodyVisible = false;

  final DateTime _sessionStart = DateTime.now();
  bool _completionShown = false;

  bool _isPaused = false;

  int _recordsSavedThisSession = 0;

  bool _recordingStarted = false;

  DateTime _currentLevelStart = DateTime.now();
  int _currentLevelReps = 0;
  RehabDifficulty _previousLevel = RehabDifficulty.easy;

  bool get _waitingHandSelect =>
      widget.action is ReachAction &&
      !(widget.action as ReachAction).handSelected;

  @override
  void initState() {
    super.initState();
    _instruction = widget.action.initialHint;
    _previousLevel = _mapDifficulty(
      widget.difficultyMeta?.level ?? DifficultyLevel.level1,
    );
    VoiceService.init();
    _start();
  }

  Future<void> _start() async {
    await _engine.init();
    if (!mounted) return;
    setState(() {});
    await _engine.startCamera();
    _engine.poseNotifier.addListener(_onPoseUpdate);

    if (!_recordingStarted) {
      _recordingStarted = true;
      ScreenRecorderService.startRecording();
    }
  }

  void _onPoseUpdate() {
    if (_isPaused) return;

    final data = _engine.poseNotifier.value;
    if (data.keypoints.length < BodyPoseEngine.numKpts) return;

    final joints = <RehabJoint, Offset>{};
    _kJointIndex.forEach((joint, idx) {
      joints[joint] = data.keypoints[idx];
    });
    final frame = BodyFrame(joints: joints);

    final visible = data.scores[5] > _scoreThreshold &&
        data.scores[6] > _scoreThreshold;

    final fb = widget.action.update(frame);

    if (mounted) {
      setState(() {
        _bodyVisible = visible;
        if (fb.scored) {
          _repCount++;
          _currentLevelReps++;
        }
        if (fb.prompt != null) _feedback = fb.prompt!;

        if (fb.leveledUp) {
          _saveCurrentLevelRecord();
          _previousLevel = _nextLevel(_previousLevel);
          _currentLevelStart = DateTime.now();
          _currentLevelReps = 0;
          _instruction = '難度提升,請繼續保持';
        }
      });

      if (fb.prompt != null) {
        VoiceService.speak(fb.prompt!);
      }
    }
  }

  void _saveCurrentLevelRecord() {
    if (widget.trainingActionMeta == null) return;

    final durationSec =
        DateTime.now().difference(_currentLevelStart).inSeconds;

    HistoryService().saveRecord(TrainingRecord(
      timestamp: DateTime.now().toString().substring(0, 16),
      actionName: widget.trainingActionMeta!.name,
      difficulty: _levelToInt(_previousLevel),
      durationSeconds: durationSec,
      mistakeLogs: const [],
      targetReps: widget.difficultyMeta?.targetReps ?? 10,
    ));

    _recordsSavedThisSession++;
  }

  RehabDifficulty _nextLevel(RehabDifficulty current) {
    switch (current) {
      case RehabDifficulty.easy:
        return RehabDifficulty.medium;
      case RehabDifficulty.medium:
        return RehabDifficulty.hard;
      case RehabDifficulty.hard:
        return RehabDifficulty.hard;
    }
  }

  int _levelToInt(RehabDifficulty d) {
    switch (d) {
      case RehabDifficulty.easy:
        return 1;
      case RehabDifficulty.medium:
        return 2;
      case RehabDifficulty.hard:
        return 3;
    }
  }

  Future<void> _switchCamera() async {
    // 🚀 樹莓派新增:如果目前是外接來源,「翻轉鏡頭」按鈕改為切回手機鏡頭
    if (_isExternalCamera) {
      await _disableExternalCamera();
      return;
    }
    await _engine.switchCamera();
    if (mounted) setState(() {});
  }

  // 🚀 樹莓派新增:開啟外接鏡頭來源(身體 + 手部)
  Future<void> _enableExternalCamera() async {
    final ip = await showPiIpDialog(context, initialIp: _lastPiIp);
    if (ip == null || ip.isEmpty) return;
    _lastPiIp = ip;

    // 手機鏡頭串流先停掉,避免兩邊同時餵畫面給同一個 engine
    try {
      final cam = _engine.cameraController;
      if (cam != null && cam.value.isStreamingImages) {
        await cam.stopImageStream();
      }
    } catch (_) {}

    _piCamera?.dispose();
    _piCamera = PiCameraSource(engine: _engine, ip: ip);
    await _piCamera!.start();

    // 🚀 手部偵測:另開一條連線接同一台樹莓派,拿手部 landmarks
    _piHand?.dispose();
    _piHand = PiHandSource(service: _handService, ip: ip);
    await _piHand!.start();

    if (!mounted) return;
    setState(() => _isExternalCamera = true);
  }

  // 🚀 樹莓派新增:切回手機內建鏡頭
  Future<void> _disableExternalCamera() async {
    await _piCamera?.stop();
    _piCamera?.dispose();
    _piCamera = null;

    // 🚀 手部偵測:一併關閉
    await _piHand?.stop();
    _piHand?.dispose();
    _piHand = null;

    try {
      final cam = _engine.cameraController;
      if (cam != null && !cam.value.isStreamingImages) {
        await cam.startImageStream((image) {});
        // startImageStream 需要透過 engine 內部方法才會接上推論,
        // 這裡改呼叫 engine 自己的 startCamera() 更安全:
      }
    } catch (_) {}
    await _engine.startCamera();

    if (!mounted) return;
    setState(() => _isExternalCamera = false);
  }

  Future<void> _handleStopButtonTap() async {
    if (_completionShown || _isPaused) return;

    setState(() => _isPaused = true);
    VoiceService.stop();

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
      setState(() => _isPaused = false);
      return;
    }

    await _handleRealEnd();
  }

  Future<void> _handleRealEnd() async {
    _completionShown = true;

    final videoPath = await ScreenRecorderService.stopRecording();

    if (_currentLevelReps >= _kMinRepsToSave) {
      _saveCurrentLevelRecord();
    }

    final durationSeconds =
        DateTime.now().difference(_sessionStart).inSeconds;

    final currentMeta = widget.trainingActionMeta ??
        kTrainingActions.firstWhere(
          (a) => a.name == widget.action.title,
          orElse: () => kTrainingActions.first,
        );
    final levelIdx = _levelToInt(_previousLevel) - 1;
    final currentDiff = (levelIdx >= 0 && levelIdx < currentMeta.difficulties.length)
        ? currentMeta.difficulties[levelIdx]
        : (widget.difficultyMeta ?? currentMeta.difficulties.first);

    bool? keepVideo;

    final result = await showDialog<_CompletionResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => CompletionDialog(
        isPaused: false,
        repCount: _repCount,
        durationSeconds: durationSeconds,
        mistakeLogs: const [],
        currentAction: currentMeta,
        currentDifficulty: currentDiff,
        hasVideo: videoPath != null,
        onVideoDecision: (keep) => keepVideo = keep,
        onRetry: () =>
            Navigator.of(dialogCtx).pop(_CompletionResult.retry()),
        onHome: () =>
            Navigator.of(dialogCtx).pop(_CompletionResult.home()),
        onStartNew: (a, d) =>
            Navigator.of(dialogCtx).pop(_CompletionResult.startNew(a, d)),
      ),
    );

    if (videoPath != null) {
      if (keepVideo == true) {
        await HistoryService()
            .updateLastRecordsVideoPath(_recordsSavedThisSession, videoPath);
      } else {
        File(videoPath).delete().catchError((e) => File(videoPath));
      }
    }

    if (!mounted || result == null) return;

    switch (result.kind) {
      case _CompletionKind.retry:
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => BodyTrainingScreen(
            action: widget.action,
            trainingActionMeta: widget.trainingActionMeta,
            difficultyMeta: widget.difficultyMeta,
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

  Future<void> _navigateToAction(
      TrainingAction action, DifficultyOption difficulty) async {
    _piCamera?.dispose();
    _piHand?.dispose(); // 🚀 樹莓派新增:離開畫面前記得釋放
    await _engine.dispose();
    if (!mounted) return;

    Widget screen;
    final diff = _mapDifficulty(difficulty.level);
    if (action.type == ActionType.wipeBody) {
      screen = BodyTrainingScreen(
        action: StandingKneeRaiseAction(
          difficulty: diff,
          targetCount: difficulty.targetReps,
        ),
        trainingActionMeta: action,
        difficultyMeta: difficulty,
      );
    } else if (action.type == ActionType.drawCircle) {
      screen = BodyTrainingScreen(
        action: DrawCircleAction(
          difficulty: diff,
          targetCount: difficulty.targetReps,
        ),
        trainingActionMeta: action,
        difficultyMeta: difficulty,
      );
    } else if (action.type == ActionType.reach) {
      screen = BodyTrainingScreen(
        action: ReachAction(
          difficulty: diff,
          targetCount: difficulty.targetReps,
        ),
        trainingActionMeta: action,
        difficultyMeta: difficulty,
      );
    } else if (action.type == ActionType.raiseBothArms) {
      screen = BodyTrainingScreen(
        action: RaiseBothArmsAction(
          difficulty: diff,
          targetCount: difficulty.targetReps,
        ),
        trainingActionMeta: action,
        difficultyMeta: difficulty,
      );
    } else if (action.type == ActionType.elbowForward) {
      screen = BodyTrainingScreen(
        action: ElbowForwardAction(
          difficulty: diff,
          targetCount: difficulty.targetReps,
        ),
        trainingActionMeta: action,
        difficultyMeta: difficulty,
      );
    } else if (action.type == ActionType.sitToStand) {
      screen = BodyTrainingScreen(
        action: SitToStandAction(
          difficulty: diff,
          targetCount: difficulty.targetReps,
        ),
        trainingActionMeta: action,
        difficultyMeta: difficulty,
      );
    } else if (action.type == ActionType.lateralStep) {
      screen = BodyTrainingScreen(
        action: LateralStepAction(
          difficulty: diff,
          targetCount: difficulty.targetReps,
        ),
        trainingActionMeta: action,
        difficultyMeta: difficulty,
      );
    } else {
      screen = TrainingScreen(action: action, difficulty: difficulty);
    }

    if (!mounted) return;
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
  void dispose() {
    if (_recordingStarted && !_completionShown) {
      ScreenRecorderService.stopRecording().then((path) {
        if (path != null) {
          File(path).delete().catchError((e) => File(path));
        }
      });
    }
    VoiceService.stop();
    _engine.poseNotifier.removeListener(_onPoseUpdate);
    _piCamera?.dispose(); // 🚀 樹莓派新增
    _piHand?.dispose(); // 🚀 樹莓派手部新增
    _handService.dispose(); // 🚀 樹莓派手部新增
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildBody()),
            _buildCoachCard(),
            _buildStatsBar(),
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
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDE0F0)),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Color(0xFF374151), size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.action.title,
              style: const TextStyle(
                color: Color(0xFF1A1D2E),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          // 🚀 樹莓派新增:外接鏡頭開關按鈕
          GestureDetector(
            onTap: _isExternalCamera
                ? _disableExternalCamera
                : _enableExternalCamera,
            child: Container(
              width: 40, height: 40,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _isExternalCamera
                    ? const Color(0xFF4A65FF)
                    : const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDE0F0)),
              ),
              child: Icon(
                Icons.videocam,
                color: _isExternalCamera ? Colors.white : const Color(0xFF374151),
                size: 20,
              ),
            ),
          ),
          GestureDetector(
            onTap: _switchCamera,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDE0F0)),
              ),
              child: const Icon(Icons.flip_camera_ios,
                  color: Color(0xFF374151), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // 🚀 樹莓派新增:外接來源時顯示 JPEG 畫面,不是 CameraPreview
    if (_isExternalCamera && _piCamera != null && _piHand != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ValueListenableBuilder<Uint8List?>(
                valueListenable: _piCamera!.latestJpeg,
                builder: (_, jpeg, __) {
                  if (jpeg == null) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF00BCD4), strokeWidth: 3),
                    );
                  }
                  return Image.memory(jpeg, fit: BoxFit.cover, gaplessPlayback: true);
                },
              ),
              ValueListenableBuilder<PoseData>(
                valueListenable: _engine.poseNotifier,
                builder: (_, data, __) {
                  return TweenAnimationBuilder<PoseData>(
                    tween: _PoseTween(end: data),
                    duration: const Duration(milliseconds: 40),
                    curve: Curves.easeOutCubic,
                    builder: (_, lerped, __) => CustomPaint(
                      painter: _SkeletonPainter(lerped, _scoreThreshold),
                    ),
                  );
                },
              ),
              // 🚀 樹莓派手部骨架:座標映射跟身體骨架用同一套(直接乘 size),
              // 確保跟畫面顯示(BoxFit.cover)、跟身體骨架完全貼合
              ValueListenableBuilder<DetectionResult>(
                valueListenable: _piHand!.handResult,
                builder: (_, hand, __) {
                  if (!hand.handDetected || hand.landmarks.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return CustomPaint(
                    painter: _PiHandSkeletonPainter(hand.landmarks),
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _piCamera!.connected,
                builder: (_, connected, __) {
                  if (connected) return const SizedBox.shrink();
                  return Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: const Center(
                      child: Text(
                        '樹莓派連線中斷,請確認網路',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  );
                },
              ),
              if (!_bodyVisible)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(
                    child: Text(
                      '請站入鏡頭範圍內',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // ── 原本手機內建鏡頭邏輯,完全不變 ──────────────────────────
    final cam = _engine.cameraController;
    if (!_engine.cameraReady.value || cam == null) {
      return const Center(
        child: CircularProgressIndicator(
            color: Color(0xFF00BCD4), strokeWidth: 3),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(cam),
            ValueListenableBuilder<PoseData>(
              valueListenable: _engine.poseNotifier,
              builder: (_, data, __) {
                return TweenAnimationBuilder<PoseData>(
                  tween: _PoseTween(end: data),
                  duration: const Duration(milliseconds: 40),
                  curve: Curves.easeOutCubic,
                  builder: (_, lerped, __) => CustomPaint(
                    painter: _SkeletonPainter(lerped, _scoreThreshold),
                  ),
                );
              },
            ),
            if (!_bodyVisible)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: Text(
                    '請站入鏡頭範圍內',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                    ),
                  ),
                ),
              ),
            if (_waitingHandSelect)
              Container(
                color: Colors.black.withValues(alpha: 0.65),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '請選擇要訓練的手',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                        ),
                      ),
                      const SizedBox(height: 36),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _handButton('左手', () {
                            setState(() {
                              (widget.action as ReachAction).selectLeftHand();
                              _feedback = '已選擇左手,請將手自然放下';
                              _instruction = '';
                            });
                          }),
                          const SizedBox(width: 28),
                          _handButton('右手', () {
                            setState(() {
                              (widget.action as ReachAction).selectRightHand();
                              _feedback = '已選擇右手,請將手自然放下';
                              _instruction = '';
                            });
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (_isPaused)
              Container(
                color: Colors.black.withValues(alpha: 0.4),
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
    );
  }

  Widget _handButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFF4A65FF),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.back_hand, color: Colors.white, size: 42),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
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
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE0F0)),
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
                    color: Color(0xFF1A1D2E),
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

  Widget _buildStatsBar() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Row(
      children: [
        Expanded(child: _statCard('完成次數', '$_repCount')),
        const SizedBox(width: 12),
        Expanded(
            child: _statCard('目前難度', widget.action.difficultyLabel)),
        const SizedBox(width: 12),
        _buildStopButton(),
      ],
    ),
  );
}

  Widget _statCard(String label, String value) {
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
            style: const TextStyle(
              color: Color(0xFF1A1D2E),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopButton() {
    return GestureDetector(
      onTap: _handleStopButtonTap,
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
        child: const Icon(Icons.stop_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

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

class _SkeletonPainter extends CustomPainter {
  final PoseData data;
  final double threshold;
  _SkeletonPainter(this.data, this.threshold);

  bool _valid(Offset p) =>
      p.dx > 0.02 && p.dx < 0.98 && p.dy > 0.02 && p.dy < 0.98;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.keypoints.isEmpty || data.scores.isEmpty) return;

    final bone = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final joint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.fill;

    for (final c in _skeletonConnections) {
      final a = c[0], b = c[1];
      if (a >= data.keypoints.length || b >= data.keypoints.length) continue;
      if (a >= data.scores.length || b >= data.scores.length) continue;
      if (data.scores[a] < threshold || data.scores[b] < threshold) continue;
      final pa = data.keypoints[a], pb = data.keypoints[b];
      if (!_valid(pa) || !_valid(pb)) continue;
      canvas.drawLine(
        Offset(pa.dx * size.width, pa.dy * size.height),
        Offset(pb.dx * size.width, pb.dy * size.height),
        bone,
      );
    }
    for (int i = 0; i < 17 && i < data.keypoints.length; i++) {
      if (i >= data.scores.length || data.scores[i] < threshold) continue;
      final p = data.keypoints[i];
      if (!_valid(p)) continue;
      canvas.drawCircle(
          Offset(p.dx * size.width, p.dy * size.height), 5, joint);
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) => true;
}

// 🚀 樹莓派手部骨架 painter
// 座標映射刻意跟 _SkeletonPainter 用同一套(直接乘 size.width/height),
// 不套用 BoxFit.contain,確保跟身體畫面(BoxFit.cover)、身體骨架三者對齊。
// 若跑起來發現方向不對(左右相反或上下顛倒),把 map() 裡的
// lm.x 改成 (1 - lm.x) 或 lm.y 改成 (1 - lm.y) 即可修正。
class _PiHandSkeletonPainter extends CustomPainter {
  final List<Landmark> landmarks;
  _PiHandSkeletonPainter(this.landmarks);

  static const _connections = [
    [0, 1], [1, 2], [2, 3], [3, 4],
    [0, 5], [5, 6], [6, 7], [7, 8],
    [0, 9], [9, 10], [10, 11], [11, 12],
    [0, 13], [13, 14], [14, 15], [15, 16],
    [0, 17], [17, 18], [18, 19], [19, 20],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    Offset map(Landmark lm) => Offset(lm.x * size.width, lm.y * size.height);

    final linePaint = Paint()
      ..color = Colors.amberAccent.withValues(alpha: 0.85)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pointPaint = Paint()
      ..color = Colors.orangeAccent
      ..style = PaintingStyle.fill;

    for (final conn in _connections) {
      if (conn[0] >= landmarks.length || conn[1] >= landmarks.length) continue;
      canvas.drawLine(map(landmarks[conn[0]]), map(landmarks[conn[1]]), linePaint);
    }

    for (final lm in landmarks) {
      canvas.drawCircle(map(lm), 5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(_PiHandSkeletonPainter old) => true;
}

class _PoseTween extends Tween<PoseData> {
  _PoseTween({super.end});

  @override
  PoseData lerp(double t) {
    final b = begin ?? PoseData.empty();
    final e = end ?? PoseData.empty();
    if (b.keypoints.isEmpty ||
        e.keypoints.isEmpty ||
        b.keypoints.length != e.keypoints.length) {
      return e;
    }
    final lerped = <Offset>[];
    for (int i = 0; i < e.keypoints.length; i++) {
      lerped.add(Offset.lerp(b.keypoints[i], e.keypoints[i], t)!);
    }
    return PoseData(lerped, e.scores);
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