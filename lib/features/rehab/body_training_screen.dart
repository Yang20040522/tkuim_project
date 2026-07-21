// lib/features/rehab/body_training_screen.dart
//
// ══════════════════════════════════════════════════════════════════
//  全身復健「共用畫面殼」
//
//  紀錄策略(方案 2 - 升級存 + 結束達標才存):
//    ✓ 升級時自動存「上一個難度」的紀錄
//    ✓ 按結束時,當前難度做 ≥3 下才存
//    ✓ 都會跳完成 dialog
//
//  ✅ 訓練開始/結束自動螢幕錄影,結束時詢問是否保留。
//     同一 session 存的所有紀錄(升級時 + 結束時)共用同一個 videoPath。
//
//  ✅ 新增:按下停止鍵先跳「暫停選單」(繼續 / 結束),
//     選「繼續」時完全不動錄影/紀錄/進度,真正接續剛剛的狀態;
//     只有選「結束」才會進入原本的完整結束流程。
// ══════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../models/pose_data.dart';
import '../../models/body_frame.dart';
import '../../models/training_action.dart';
import '../../services/body_pose_engine.dart';
import '../../services/history_service.dart';
import '../../services/screen_recorder_service.dart';
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

  int _repCount = 0;
  String _feedback = '請將身體放入鏡頭範圍內';
  late String _instruction;
  bool _bodyVisible = false;

  final DateTime _sessionStart = DateTime.now();
  bool _completionShown = false;

  // 是否正暫停中(暫停選單開啟期間為 true,偵測/計次會被忽略)
  bool _isPaused = false;

  // 這個 session 目前已經存了幾筆紀錄(升級時 + 結束時的加總),
  // 用來知道 stop 時要回頭更新「最後幾筆」紀錄的 videoPath
  int _recordsSavedThisSession = 0;

  // 錄影是否已經開始(避免重複呼叫)
  bool _recordingStarted = false;

  // ─── 當前難度的追蹤 ───────────────────────────────────────
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

    // 相機開始後就開始螢幕錄影(附加功能,失敗不影響訓練本身)
    if (!_recordingStarted) {
      _recordingStarted = true;
      ScreenRecorderService.startRecording();
    }
  }

  void _onPoseUpdate() {
    // 暫停中:不處理任何偵測結果,計次/回饋完全凍結,
    // 這樣「繼續」時才能真的從原本狀態接著做,而不是漏掉或多算。
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

  // ─── 存當前難度的紀錄(升級瞬間 + 結束達標時呼叫)─────
  // 注意:這裡先不帶 videoPath,等 session 真正結束、使用者決定
  // 保留/不保留錄影後,再由 HistoryService.updateLastRecordsVideoPath
  // 回頭把這個 session 存的所有紀錄一次補上。
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
      targetReps: widget.difficultyMeta?.targetReps ?? 10, // ✅ 新增
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
    await _engine.switchCamera();
    if (mounted) setState(() {});
  }

  // ─── 按停止鍵觸發:先跳「暫停選單」,不動任何狀態 ─────────
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
      // 使用者選「繼續」,或用其他方式關掉選單(不算數,一律視為繼續)
      setState(() => _isPaused = false);
      return;
    }

    // 選「結束」→ 進入原本的完整結束流程
    await _handleRealEnd();
  }

  // ─── 真正的結束流程(停止錄影、存紀錄、跳完成 dialog)─────
  Future<void> _handleRealEnd() async {
    _completionShown = true;

    // 停止錄影,拿到暫存檔案路徑(如果有錄成功的話)
    final videoPath = await ScreenRecorderService.stopRecording();

    // 當前難度做 ≥ 3 下 → 存當前難度的紀錄
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
    //final currentDiff = widget.difficultyMeta ??
        //currentMeta.difficulties.first;
    // ✅ 改成這樣:用「真正做到的難度」反查對應的 DifficultyOption
    final levelIdx = _levelToInt(_previousLevel) - 1;
    final currentDiff = (levelIdx >= 0 && levelIdx < currentMeta.difficulties.length)
        ? currentMeta.difficulties[levelIdx]
        : (widget.difficultyMeta ?? currentMeta.difficulties.first);

    // 使用者在 dialog 裡選擇的結果(保留/不保留),預設 null = 沒選(視同不保留)
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

    // 回頭把這個 session 存的所有紀錄補上(或清掉)videoPath
    if (videoPath != null) {
      if (keepVideo == true) {
        await HistoryService()
            .updateLastRecordsVideoPath(_recordsSavedThisSession, videoPath);
      } else {
        // 使用者選不保留(或沒做決定)→ 刪掉暫存檔案,紀錄的 videoPath 維持 null
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
    // 保險:如果畫面被意外關掉(例如手機返回鍵、系統中斷)而沒有走到
    // _handleRealEnd,錄影可能還在跑,這裡補一次停止,避免背景一直錄影。
    // 這種非正常結束的情況,不詢問保留與否,直接視為不保留。
    if (_recordingStarted && !_completionShown) {
      ScreenRecorderService.stopRecording().then((path) {
        if (path != null) {
          File(path).delete().catchError((e) => File(path));
        }
      });
    }
    VoiceService.stop();
    _engine.poseNotifier.removeListener(_onPoseUpdate);
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

// ── 暫停選單 dialog:只有「繼續」跟「結束」兩個選項 ──────────────
// 目的是讓「暫停」真正只是暫停(不動任何進度/錄影/紀錄),
// 只有選「結束」才會進入下一步的完整結束流程。
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