// lib/features/rehab/body_training_screen.dart
//
// ══════════════════════════════════════════════════════════════════
//  全身復健「共用畫面殼」
//  🚀 支援切換鏡頭來源(手機內建 / 樹莓派外接)
//  🚀 樹莓派模式下,手部骨架改走樹莓派偵測(PiHandSource),
//     與身體骨架共用同一套座標映射方式,確保兩者貼合對齊
//  🚀 修正:_SkeletonPainter / _PiHandSkeletonPainter 加上 sourceSize,
//     讓骨架點位能跟 Image.memory(fit: BoxFit.cover) 的裁切/縮放對齊。
//     原本座標是 landmark 的 0~1 正規化值直接乘容器尺寸,但畫面顯示時
//     用 BoxFit.cover 把原始 JPEG(長寬比通常跟容器不同)裁切填滿容器,
//     兩套邏輯沒有對齊,骨架才會貼不上身體/手指。
//     手機鏡頭(CameraPreview)路徑完全不傳 sourceSize,行為不受影響。
//
//  🆕 2026-08-22:換動作時把 autoLevelUp 一併帶到下一個畫面
//     - CompletionDialog 的 onStartNew 簽名擴充為 (action, difficulty, autoLevelUp)
//     - retry / startNew 都改用「當時使用者選的」autoLevelUp,
//       不再一律沿用 widget.autoLevelUp
//     - _navigateToAction 多一個 autoLevelUp 參數,並把方法內所有
//       widget.autoLevelUp 改成新參數 autoLevelUp
//
//  🛠️ 2026-08-27:修正 _buildLevelUpOverlay() 括號結構錯誤
//     - Material 底下多包了一層 Positioned.fill,但 Material 不是 Stack,
//       Positioned 只能直接放在 Stack 裡,造成 build 錯誤。
//       這個 overlay 本來就已經被包在最外層 build() 的 Stack 裡了,
//       所以這層 Positioned.fill 是多餘的,直接拿掉,讓 Material 直接包 Container。
//
//  🩹 2026-08-31:修正兩個歷史紀錄相關 bug
//     ① timestamp 精度從「分鐘」(substring 0,16)拉到「秒」(substring 0,19):
//        自動升級難度時,初級→中級→高級常在同一分鐘內連續完成,
//        造成三筆紀錄 timestamp 完全相同,history_screen.dart 的
//        Dismissible key: ValueKey(record.timestamp) 會把它們當成同一個
//        widget,只顯示其中一筆,其餘被吃掉不會顯示。
//     ② 升級難度時 _repCount 沒有跟著歸零,只重置了 _currentLevelReps,
//        導致畫面上「完成次數」會把前面難度的次數一起累加顯示
//        (例如初級 1 下 + 中級 1 下 → 顯示 2)。已在自動升級與手動確認
//        升級兩個路徑都補上 _repCount = 0。
//
//  🆕 2026-09-06:新增「選患側 → 選簡單/困難版」的選腳畫面
//     - 站姿抬腳式(StandingKneeRaiseAction)、側跨步(LateralStepAction)
//       都改成需要先選腳才會開始偵測(legAndModeSelected),但畫面原本
//       完全沒有對應的選腳 UI,導致這兩個動作永遠卡在「請先選擇...」,
//       完成次數永遠 0。
//     - 新增 _waitingLegSelect,寫法比照既有的 _waitingHandSelect
//       (ReachAction 選手流程):偵測到 action 是 LegRoleSelectable 且
//       還沒選完,就在畫面上蓋一層選擇 UI 擋住偵測,選完自動消失。
//     - 兩個下肢動作都實作同一個 LegRoleSelectable 介面,所以這裡完全
//       不用分辨底下是哪一個動作類別,共用同一套按鈕邏輯。
//
//  🔀 2026-09-07:AI 標準模板採 opt-in selectedTemplate。
//     一般訓練不收集 trajectory；AI 模式只在既有 scored rep 後比較。
//
//  🛠️ 2026-09-09:修正全身動作「有骨架但不計次」的共用判定鏈。
//     - BodyTrainingScreen 不再硬性要求 133 點完整，身體 0~16 足夠就判定。
//     - 只把可信且有限值的身體關節送進 BodyRehabAction。
//     - 原本 action.update() 改為先執行，AI 模板分析保持被動附加。
//     - 樹莓派模式補回 Reach/下肢選擇遮罩。
//     - 樹莓派切回手機時只由 BodyPoseEngine 啟動 image stream，避免重複啟動。
// ══════════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:typed_data'; // 用到 Uint8List
import 'dart:ui' show Size; // 🚀 新增:骨架對齊用
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
import '../../features/account/app_session.dart';
import '../../features/plan/plan_repository.dart';
import '../../features/analysis/body/body_motion_template.dart';
import '../../features/analysis/body/body_rep_trajectory_collector.dart';
import '../../features/analysis/body/body_template_analyzer.dart';
import '../../features/analysis/body/body_template_deviation_formatter.dart';
import '../../features/analysis/models/environment_metadata.dart';
import '../../features/analysis/models/motion_action_registry.dart';
import '../../features/analysis/widgets/template_training_mode_dialog.dart';

// 🖥️ 電視投放新增
import 'dart:async';
//import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../features/tv_cast/webrtc_service.dart';
import '../../features/tv_cast/socket_server_service.dart';
import '../../features/tv_cast/socket_client_service.dart';
import '../../controllers/rehab_session_controller.dart';
import '../training/training_preview_screen.dart';

// 歷史紀錄現在依實際完成次數判斷：目前難度有完成至少 1 下就保存。

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
  final BodyMotionTemplate? selectedTemplate;

  final bool isDisplay; // 🖥️ 電視投放新增:true = 這台當電視顯示端
  final bool autoLevelUp; // 🆕 true=自動升級(舊行為), false=跳出詢問讓使用者決定

  const BodyTrainingScreen({
    super.key,
    required this.action,
    this.trainingActionMeta,
    this.difficultyMeta,
    this.selectedTemplate,
    this.isDisplay = false, // 🖥️ 電視投放新增
    this.autoLevelUp = true, // 🆕 預設 true,不影響現在其他呼叫這個畫面的地方
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

  // 🖥️ 電視投放新增
  final _serverService = SocketServerService();
  final _clientService = SocketClientService();
  final _rtcService = WebRtcService();
  final _remoteRenderer = RTCVideoRenderer();
  StreamSubscription? _socketSub;
  final ValueNotifier<RehabSessionState> _remoteState =
      ValueNotifier(const RehabSessionState());

  int _repCount = 0;
  String _feedback = '請將身體放入鏡頭範圍內';
  late String _instruction;
  bool _bodyVisible = false;

  // 🛠️ 2026-09-09：避免「骨架明明有抓到，畫面卻一直顯示請站入鏡頭範圍內」。
  //
  // _bodyVisible 只控制 UI 遮罩，不應要求左右肩同時高分。
  // RTMPose 某一個肩膀短暫掉分時，其他骨架仍可能正常。
  int _bodyMissingFrames = 0;
  static const int _bodyMissingFrameTolerance = 10;
  static const double _bodyVisibilityScoreThreshold = 0.15;

  final DateTime _sessionStart = DateTime.now();
  bool _completionShown = false;

  bool _isPaused = false;
  bool _isSwitchingCameraUI = false;

  int _recordsSavedThisSession = 0;

  // 自動升級時，同一場訓練的所有難度共用同一個 sessionId。
  // 手動升級則每一階在存檔時建立自己的 manual sessionId。
  late final String _automaticHistorySessionId;

  bool _recordingStarted = false;

  bool _levelUpDialogShowing = false;
  bool _hasNextLevel = false; // 🆕
  String _nextLevelLabel = ''; // 🆕
  final TextEditingController _levelUpRepsController =
      TextEditingController(); // 🆕

  DateTime _currentLevelStart = DateTime.now();
  int _currentLevelReps = 0;
  int _currentLevelTargetReps = 0; // 🆕 追蹤「目前這一階」實際的目標次數(含自訂值)
  RehabDifficulty _previousLevel = RehabDifficulty.easy;

  // Passive template analysis. Existing action remains authoritative for reps.
  final BodyRepTrajectoryCollector _aiTrajectoryCollector =
      BodyRepTrajectoryCollector();
  final BodyTemplateAnalyzer _bodyTemplateAnalyzer =
      const BodyTemplateAnalyzer();
  final Stopwatch _aiSessionClock = Stopwatch();
  BodyTemplateAnalysisResult? _lastAiAnalysis;
  BodySide? _selectedAiTrainedSide;
  BodySide? _selectedAiMovementSide;
  late final bool _templateAnalysisEnabled;

  bool get _usesTemplateAnalysis => _templateAnalysisEnabled;

  bool _resolveTemplateAnalysisCapability() {
    if (widget.isDisplay || widget.selectedTemplate == null) return false;
    final capability = MotionActionRegistry.resolve(
      widget.trainingActionMeta?.type.name ?? widget.action.title,
      modelType: MotionTemplateModelType.body,
    );
    final templateCapability = MotionActionRegistry.resolve(
          widget.selectedTemplate!.actionId,
          modelType: MotionTemplateModelType.body,
        ) ??
        MotionActionRegistry.resolve(
          widget.selectedTemplate!.actionType,
          modelType: MotionTemplateModelType.body,
        );
    return capability?.postRepAnalyzerKind ==
            PostRepAnalyzerKind.bodyTrajectory &&
        templateCapability?.actionId == capability?.actionId;
  }

  bool get _waitingHandSelect =>
      widget.action is ReachAction &&
      !(widget.action as ReachAction).handSelected;

  // 🆕 選腳:站姿抬腳式、側跨步都實作 LegRoleSelectable,共用同一套選腳畫面
  bool get _waitingLegSelect =>
      widget.action is LegRoleSelectable &&
      !(widget.action as LegRoleSelectable).legAndModeSelected;

  @override
  void initState() {
    super.initState();

    _automaticHistorySessionId =
        'auto:${DateTime.now().microsecondsSinceEpoch}';
    _templateAnalysisEnabled = _resolveTemplateAnalysisCapability();
    _currentLevelTargetReps = widget.difficultyMeta?.targetReps ?? 10; // 🆕
    _instruction = widget.action.initialHint;
    _previousLevel = _mapDifficulty(
      widget.difficultyMeta?.level ?? DifficultyLevel.level1,
    );
    VoiceService.init();
    if (_usesTemplateAnalysis) {
      _aiSessionClock.start();
    }
    _start();

    // 🖥️ 電視投放:只有真的連了電視才初始化,沒連就完全跳過(省效能)
    final bool tvConnected =
        _clientService.isConnected || _serverService.isClientConnected;
    if (tvConnected) {
      _initRtc();
      if (_clientService.isConnected) {
        _socketSub = _clientService.messages.listen(_handleRemoteCommand);
      } else if (_serverService.isClientConnected) {
        _socketSub = _serverService.messages.listen(_handleRemoteCommand);
      }
    }

    // 🖥️ 電視投放新增:控制端進訓練時,通知電視開對應的顯示端畫面
    if (!widget.isDisplay) {
      final startMsg = {
        'type': 'START_TRAINING',
        'actionName': widget.trainingActionMeta?.name ?? widget.action.title,
        'difficultyLevel': widget.difficultyMeta?.level.name ?? 'level1',
      };
      if (_clientService.isConnected) {
        _clientService.sendCommand(startMsg);
      } else if (_serverService.isClientConnected) {
        _serverService.sendMessage(startMsg);
      }
    }
  }

  Future<void> _start() async {
    // 🖥️ 電視投放新增:顯示端不開相機、不載模型,只吃遠端資料
    await _engine.init(asReceiver: widget.isDisplay);
    if (!mounted) return;
    setState(() {});
    if (widget.isDisplay) return; // 🖥️ 顯示端到此為止

    await _engine.startCamera();
    _engine.poseNotifier.addListener(_onPoseUpdate); // ← 偵測核心,補回來
    // 🖥️ 電視投放:只有連了電視的控制端才傳畫面,沒連不生成 JPEG(省效能)
    if (_clientService.isConnected || _serverService.isClientConnected) {
      _engine.imageNotifier.addListener(_onImageUpdate);
      _engine.castEnabled = true;
    }

    if (!_recordingStarted) {
      _recordingStarted = true;
      ScreenRecorderService.startRecording();
    }
  }

  void _onPoseUpdate() {
    if (_isPaused) return;

    final data = _engine.poseNotifier.value;

    // 🛠️ 2026-09-09：全身復健動作實際只使用 RTMPose 的 0~16 身體點。
    // 不再要求整包 133 點全部存在，避免臉部/手部任一點缺失時，
    // 明明身體骨架完整卻直接 return，導致所有 BodyRehabAction 都不執行。
    const int bodyLandmarkCount = 17;
    if (data.keypoints.length < bodyLandmarkCount ||
        data.scores.length < bodyLandmarkCount) {
      // 偶爾少一幀時，不要立刻把畫面蓋黑。
      // 只有連續多幀資料都不足，才判定人真的離開鏡頭。
      _bodyMissingFrames++;

      if (mounted &&
          _bodyVisible &&
          _bodyMissingFrames >= _bodyMissingFrameTolerance) {
        setState(() {
          _bodyVisible = false;
        });
      }

      debugPrint(
        'BodyTrainingScreen：姿勢資料不足 '
        '(keypoints=${data.keypoints.length}, scores=${data.scores.length}, '
        'missingFrames=$_bodyMissingFrames)',
      );
      return;
    }

    // 只把「索引存在 + 分數可信 + 座標有效」的關節交給動作判定。
    // BodyRehabAction 本身若缺必要關節會回 RehabFeedback.none，
    // 比把缺失點塞成 Offset.zero 更安全。
    final joints = <RehabJoint, Offset>{};
    _kJointIndex.forEach((joint, idx) {
      if (idx >= data.keypoints.length || idx >= data.scores.length) return;

      final point = data.keypoints[idx];
      final score = data.scores[idx];
      if (!point.dx.isFinite || !point.dy.isFinite || !score.isFinite) return;
      if (score < _scoreThreshold) return;

      joints[joint] = point;
    });
    final frame = BodyFrame(joints: joints);

    // ── UI 用「人在不在鏡頭內」判定 ─────────────────────────────
    //
    // 舊版要求左肩 + 右肩都高於 threshold，
    // 只要其中一邊肩膀短暫掉分，就會立刻顯示黑色遮罩。
    //
    // 新版改看主要身體點（肩、肘、腕、髖、膝、踝）：
    // 至少 4 個可靠點，且至少有 1 個肩/髖軀幹點，就視為人在畫面內。
    // 這只控制 UI；真正動作判定仍由各 Action 自己決定。
    const bodyVisibilityIndexes = <int>[
      5, 6,   // 肩
      7, 8,   // 肘
      9, 10,  // 手腕
      11, 12, // 髖
      13, 14, // 膝
      15, 16, // 腳踝
    ];

    const torsoVisibilityIndexes = <int>[
      5, 6,   // 肩
      11, 12, // 髖
    ];

    int visibleBodyJointCount = 0;
    for (final idx in bodyVisibilityIndexes) {
      if (idx < data.scores.length &&
          data.scores[idx].isFinite &&
          data.scores[idx] >= _bodyVisibilityScoreThreshold) {
        visibleBodyJointCount++;
      }
    }

    int visibleTorsoJointCount = 0;
    for (final idx in torsoVisibilityIndexes) {
      if (idx < data.scores.length &&
          data.scores[idx].isFinite &&
          data.scores[idx] >= _bodyVisibilityScoreThreshold) {
        visibleTorsoJointCount++;
      }
    }

    final detectedNow =
        visibleBodyJointCount >= 4 && visibleTorsoJointCount >= 1;

    if (detectedNow) {
      _bodyMissingFrames = 0;
    } else {
      _bodyMissingFrames++;
    }

    // 已經偵測到人時，允許短暫掉點約 10 幀，
    // 避免骨架分數小幅波動就讓畫面忽明忽暗。
    final visible = detectedNow ||
        (_bodyVisible &&
            _bodyMissingFrames < _bodyMissingFrameTolerance);

    // 🛠️ 原本動作判定是整個訓練最重要的主流程。
    // 先執行 action.update()，AI 標準模板分析改成被動附加，
    // 即使未來 AI 收集/分析出錯，也不會擋住原本的計次功能。
    RehabFeedback fb;
    try {
      fb = widget.action.update(frame);
    } catch (error, stackTrace) {
      debugPrint('Body action 判定失敗：$error');
      debugPrintStack(stackTrace: stackTrace);
      fb = RehabFeedback.none;
    }

    int? aiTimestampMs;
    if (_usesTemplateAnalysis) {
      aiTimestampMs = _aiSessionClock.elapsedMilliseconds;
      try {
        _aiTrajectoryCollector.addFrame(
          timestampMs: aiTimestampMs,
          landmarks: data.keypoints,
          scores: data.scores,
        );
      } catch (error) {
        // AI 是附加功能；收集失敗不能影響原本動作計次。
        debugPrint('Body AI 軌跡收集失敗：$error');
      }
    }

    BodyTemplateAnalysisResult? completedRepAnalysis;
    if (_usesTemplateAnalysis && fb.scored) {
      try {
        // Always retain the authoritative scored frame even if it falls inside
        // the normal 100 ms sampling interval.
        _aiTrajectoryCollector.addFrame(
          timestampMs: aiTimestampMs!,
          landmarks: data.keypoints,
          scores: data.scores,
          force: true,
        );
        final completedRep = _aiTrajectoryCollector.takeCompletedRep();
        completedRepAnalysis = _bodyTemplateAnalyzer.analyze(
          template: widget.selectedTemplate!,
          patientSamples: completedRep,
          currentCameraView: _isExternalCamera ? null : CameraView.front,
          movementSide: _selectedAiMovementSide,
        );
      } catch (error) {
        debugPrint('Body AI 模板分析失敗：$error');
        completedRepAnalysis = BodyTemplateAnalysisResult.unavailable(
          enoughData: false,
          reason: '本次 AI 動作品質暫時無法分析。',
        );
      }
    }

    bool justReachedLevelUp = false;

    if (mounted) {
      setState(() {
        _bodyVisible = visible;
        if (fb.scored) {
          _repCount++;
          _currentLevelReps++;
        }
        if (fb.prompt != null) _feedback = fb.prompt!;
        if (completedRepAnalysis != null) {
          _lastAiAnalysis = completedRepAnalysis;
        }

        if (fb.leveledUp) {
          justReachedLevelUp = true;
        }
      });

      // 🆕 達標了 → 依照 autoLevelUp 開關決定「自動升級」還是「跳出詢問」
      if (justReachedLevelUp) {
        final action = widget.action;
        final controllable = action is LevelUpControllable
            ? action as LevelUpControllable
            : null;

        if (widget.autoLevelUp) {
          // 先判斷目前這階之後還有沒有下一階(跟手動模式同一套算法)
          final currentMeta = widget.trainingActionMeta ??
              kTrainingActions.firstWhere(
                (a) => a.name == widget.action.title,
                orElse: () => kTrainingActions.first,
              );
          final currentLevelIdx = _levelToInt(_previousLevel) - 1;
          final hasNextLevel = currentLevelIdx >= 0 &&
              currentLevelIdx + 1 < currentMeta.difficulties.length;

          if (hasNextLevel) {
            // 🛠️ 2026-09-09：
            // 使用者如果一開始自訂「2 次」，自動升級後也必須維持 2 次，
            // 不能偷偷改回下一階設定檔裡預設的 8 / 6 次。
            //
            // 先保存目前真正使用中的目標次數，再用同一個值升級 action。
            final selectedTargetReps = _currentLevelTargetReps;

            // 升級前先把這一階存下來。
            _saveCurrentLevelRecord();

            // 把使用者選的次數傳進下一階 action，避免 action 內部回到預設值。
            controllable?.confirmLevelUp(
              customTargetReps: selectedTargetReps,
            );

            setState(() {
              _previousLevel = _nextLevel(_previousLevel);
              _currentLevelStart = DateTime.now();
              _currentLevelReps = 0;
              _repCount = 0;

              // 關鍵：下一階繼續使用使用者原本選的次數。
              _currentLevelTargetReps = selectedTargetReps;

              _instruction = '難度提升,請繼續保持';
            });
          } else {
            // 已經是最高難度 → 自動結束整場訓練
            // (最後這階的紀錄會由 _handleRealEnd 內的 _saveCurrentLevelRecord 存)
            setState(() => _isPaused = true); // 擋掉後續 pose frame,避免重複進結束流程
            _handleRealEnd();
          }
        } else if (!_levelUpDialogShowing) {
          _handleLevelUpDetected();
        }
      }

      // 🖥️ 電視投放新增:控制端把骨架+狀態傳給電視
      if (_clientService.isConnected || _serverService.isClientConnected) {
        final poseMsg = {
          'type': 'POSE_UPDATE',
          'keypoints': data.keypoints.map((e) => [e.dx, e.dy]).toList(),
          'scores': data.scores,
        };
        final statusMsg = {
          'type': 'TRAINING_UPDATE',
          'repCount': _repCount,
          'feedback': _feedback,
          'instruction': _instruction,
        };
        if (_clientService.isConnected) {
          _clientService.sendCommand(poseMsg);
          _clientService.sendCommand(statusMsg);
        } else {
          _serverService.sendMessage(poseMsg);
          _serverService.sendMessage(statusMsg);
        }
      }

      if (fb.prompt != null) {
        VoiceService.speak(fb.prompt!);
      }
    }
  }

  // 🖥️ 電視投放新增:WebRTC + binary(JPEG)接收
  Future<void> _initRtc() async {
    await _remoteRenderer.initialize();
    _rtcService.onRemoteStream.listen((stream) {
      if (mounted) setState(() => _remoteRenderer.srcObject = stream);
    });

    if (_clientService.isConnected) {
      _clientService.binaryMessages.listen((data) {
        if (mounted && widget.isDisplay) _engine.imageNotifier.value = data;
      });
    } else if (_serverService.isClientConnected) {
      _serverService.binaryMessages.listen((data) {
        if (mounted && widget.isDisplay) _engine.imageNotifier.value = data;
      });
    }

    if (!widget.isDisplay) {
      await _rtcService.init(isController: true);
    }
  }

  // 🖥️ 電視投放新增:控制端把手機畫面 JPEG 傳給電視
  void _onImageUpdate() {
    if (widget.isDisplay) return;
    final jpeg = _engine.imageNotifier.value;
    if (jpeg == null) return;
    if (_clientService.isConnected) {
      _clientService.sendBinary(jpeg);
    } else if (_serverService.isClientConnected) {
      _serverService.sendBinary(jpeg);
    }
  }

  // 🖥️ 電視投放新增:顯示端收遠端指令
  void _handleRemoteCommand(Map<String, dynamic> msg) {
    if (!mounted || !widget.isDisplay) return;
    final type = msg['type'];
    if (type == 'POSE_UPDATE') {
      final kp = (msg['keypoints'] as List)
          .map((e) => Offset(e[0].toDouble(), e[1].toDouble()))
          .toList();
      final sc = (msg['scores'] as List).map((e) => e.toDouble()).toList();
      _engine.updateFromRemote(kp, List<double>.from(sc));
    } else if (type == 'TRAINING_UPDATE') {
      final c = _remoteState.value;
      _remoteState.value = c.copyWith(
        repCount: msg['repCount'] ?? c.repCount,
        feedback: msg['feedback'] ?? c.feedback,
        instruction: msg['instruction'] ?? c.instruction,
      );
    } else if (type == 'RTC_SIGNAL') {
      _rtcService.handleSignal(msg['signal']);
    } else if (type == 'STOP') {
      Navigator.of(context).pop();
    }
  }

  // 🆕 達標時呼叫:跳出「要不要升級」詢問視窗
  void _handleLevelUpDetected() {
    if (_levelUpDialogShowing) return;

    final currentMeta = widget.trainingActionMeta ??
        kTrainingActions.firstWhere(
          (a) => a.name == widget.action.title,
          orElse: () => kTrainingActions.first,
        );

    final currentLevelIdx = _levelToInt(_previousLevel) - 1;
    final nextLevelIdx = currentLevelIdx + 1;
    final hasNextLevel =
        currentLevelIdx >= 0 && nextLevelIdx < currentMeta.difficulties.length;
    final nextDifficulty =
        hasNextLevel ? currentMeta.difficulties[nextLevelIdx] : null;

    setState(() {
      _isPaused = true;
      _levelUpDialogShowing = true;
      _hasNextLevel = hasNextLevel;
      _nextLevelLabel = nextDifficulty?.label ?? '';

      // 🛠️ 手動升級視窗也沿用目前使用者選的次數。
      // 例如一開始選 2 次，升級視窗預設仍顯示 2；
      // 使用者若真的想改成別的次數，再自行修改即可。
      _levelUpRepsController.text = '$_currentLevelTargetReps';
    });
    VoiceService.stop();
  }

  void _confirmLevelUp() {
    //final currentMeta = widget.trainingActionMeta ??
    kTrainingActions.firstWhere(
      (a) => a.name == widget.action.title,
      orElse: () => kTrainingActions.first,
    );
    //final currentLevelIdx = _levelToInt(_previousLevel) - 1;
    //final nextLevelIdx = currentLevelIdx + 1;
    //final nextDifficulty = currentMeta.difficulties[nextLevelIdx];

    final action = widget.action;
    final controllable =
        action is LevelUpControllable ? action as LevelUpControllable : null;

    _saveCurrentLevelRecord();
    final customReps = int.tryParse(_levelUpRepsController.text);
    controllable?.confirmLevelUp(
      customTargetReps:
          (customReps != null && customReps > 0) ? customReps : null,
    );

    setState(() {
      _levelUpDialogShowing = false;
      _previousLevel = _nextLevel(_previousLevel);
      _currentLevelStart = DateTime.now();
      _currentLevelReps = 0;
      _repCount = 0;
      // 使用者有輸入新值就採用新值；沒有有效輸入則維持原本自訂次數。
      _currentLevelTargetReps =
          (customReps != null && customReps > 0)
              ? customReps
              : _currentLevelTargetReps;
      _instruction = '難度提升,請繼續保持';
      _isPaused = false;
    });
  }

  void _declineLevelUp() {
    setState(() {
      _levelUpDialogShowing = false;
    });
    _handleRealEnd(); // 🆕 不繼續練,直接進入結束流程(存紀錄、跳完成畫面)
  }

  String _historySessionIdForCurrentRecord() {
    if (widget.autoLevelUp) {
      return _automaticHistorySessionId;
    }

    // 手動升級：每一階都必須是獨立紀錄，不能跟下一階合併。
    return 'manual:${DateTime.now().microsecondsSinceEpoch}';
  }

  void _saveCurrentLevelRecord() {
    if (widget.trainingActionMeta == null) return;

    final durationSec = DateTime.now().difference(_currentLevelStart).inSeconds;

    HistoryService().saveRecord(
      TrainingRecord(
        sessionId: _historySessionIdForCurrentRecord(),
        timestamp: DateTime.now().toString().substring(0, 19),
        actionName: widget.trainingActionMeta!.name,
        difficulty: _levelToInt(_previousLevel),
        durationSeconds: durationSec,
        mistakeLogs: const [],
        completedReps: _currentLevelReps,
        targetReps: _currentLevelTargetReps,
      ),
    );

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
    if (_isSwitchingCameraUI) return; // 🆕 UI層直接擋,連進到engine都不用
    _resetAiForSourceChange();
    setState(() => _isSwitchingCameraUI = true); // 🆕

    if (_isExternalCamera) {
      await _disableExternalCamera();
    } else {
      await _engine.switchCamera();
      if (mounted) setState(() {});
    }

    if (mounted) setState(() => _isSwitchingCameraUI = false); // 🆕
  }

  // 🚀 樹莓派新增:開啟外接鏡頭來源(身體 + 手部)
  Future<void> _enableExternalCamera() async {
    final ip = await showPiIpDialog(context, initialIp: _lastPiIp);
    if (ip == null || ip.isEmpty) return;
    _lastPiIp = ip;
    _resetAiForSourceChange();

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
    _resetAiForSourceChange();
    await _piCamera?.stop();
    _piCamera?.dispose();
    _piCamera = null;

    // 🚀 手部偵測:一併關閉
    await _piHand?.stop();
    _piHand?.dispose();
    _piHand = null;

    // 🛠️ 2026-09-09：不要先開一條空的 image stream。
    // 舊版先 cam.startImageStream((image) {})，下一行再呼叫 engine.startCamera()，
    // 等於同一個 CameraController 連續啟動兩次串流；部分裝置會因此拋錯，
    // 切回手機鏡頭後只剩預覽、沒有再餵 RTMPose 推論。
    try {
      final cam = _engine.cameraController;
      if (cam != null && !cam.value.isStreamingImages) {
        await _engine.startCamera();
      }
    } catch (error) {
      debugPrint('切回手機鏡頭失敗：$error');
    }

    if (!mounted) return;
    setState(() => _isExternalCamera = false);
  }

  Future<void> _handleStopButtonTap() async {
    if (_completionShown || _isPaused) return;

    _aiTrajectoryCollector.reset();
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
    _aiTrajectoryCollector.reset();

    final videoPath = await ScreenRecorderService.stopRecording();

    // 🛠️ 2026-09-09：
    // 舊版要求目前難度至少完成 3 下才存紀錄。
    // 但現在使用者可以自訂目標次數，例如只選 1 次或 2 次，
    // 最高難度完成後會直接進入 _handleRealEnd()，
    // 因此 1/1、2/2 反而會被「至少 3 下」這個舊限制擋掉，
    // 導致 Lv.3 明明完成卻沒有歷史紀錄。
    //
    // 新規則：只要目前這一階真的有完成至少 1 下，就保存。
    if (_currentLevelReps > 0) {
      _saveCurrentLevelRecord();
    }

    // ✅ 新增
    final patientId = AppSession.userId?.trim();
    if (patientId != null && patientId.isNotEmpty) {
      try {
        await markPlanItemDoneByActionName(
          patientId: patientId,
          actionName: widget.trainingActionMeta?.name ?? widget.action.title,
        );
      } on Object {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('讀取或儲存復健計畫失敗')),
          );
        }
      }
    }

    final durationSeconds = DateTime.now().difference(_sessionStart).inSeconds;

    final currentMeta = widget.trainingActionMeta ??
        kTrainingActions.firstWhere(
          (a) => a.name == widget.action.title,
          orElse: () => kTrainingActions.first,
        );
    final levelIdx = _levelToInt(_previousLevel) - 1;
    final currentDiff =
        (levelIdx >= 0 && levelIdx < currentMeta.difficulties.length)
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
        onRetry: () => Navigator.of(dialogCtx).pop(_CompletionResult.retry()),
        onHome: () => Navigator.of(dialogCtx).pop(_CompletionResult.home()),
        onStartNew: (a, d, autoLvl) => Navigator.of(dialogCtx)
            .pop(_CompletionResult.startNew(a, d, autoLvl)), // 🆕
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
            selectedTemplate: widget.selectedTemplate,
            autoLevelUp: widget.autoLevelUp, // 🆕(原本漏了,補上)
          ),
        ));
        break;
      case _CompletionKind.home:
        Navigator.of(context).pop();
        break;
      case _CompletionKind.startNew:
        _navigateToAction(
            result.action!, result.difficulty!, result.autoLevelUp!); // 🆕
        break;
    }
  }

  Future<void> _navigateToAction(TrainingAction action,
      DifficultyOption difficulty, bool autoLevelUp) async {
    // 🆕 多一個參數
    final templateSelection = await MotionTemplateTrainingPicker.choose(
      context: context,
      action: action,
    );
    if (!mounted || templateSelection == null) return;

    _aiTrajectoryCollector.reset();
    _engine.poseNotifier
        .removeListener(_onPoseUpdate); // 🆕 先停止監聽,避免dispose過程中還觸發更新
    _piCamera?.dispose();
    _piHand?.dispose(); // 🚀 樹莓派新增:離開畫面前記得釋放
    await _engine.dispose();
    // 🆕 給相機資源多一點時間真正釋放乾淨,避免畫面切換太快
    //    導致 Flutter 內部元件清單對不起來而閃紅畫面
    await Future.delayed(const Duration(milliseconds: 300));

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
        selectedTemplate: templateSelection.selectedBodyTemplate,
        autoLevelUp: autoLevelUp, // 🆕(原本是 widget.autoLevelUp)
      );
    } else if (action.type == ActionType.drawCircle) {
      screen = BodyTrainingScreen(
        action: DrawCircleAction(
          difficulty: diff,
          targetCount: difficulty.targetReps,
        ),
        trainingActionMeta: action,
        difficultyMeta: difficulty,
        autoLevelUp: autoLevelUp, // 🆕
      );
    } else if (action.type == ActionType.reach) {
      screen = BodyTrainingScreen(
        action: ReachAction(
          difficulty: diff,
          targetCount: difficulty.targetReps,
        ),
        trainingActionMeta: action,
        difficultyMeta: difficulty,
        autoLevelUp: autoLevelUp, // 🆕
      );
    } else if (action.type == ActionType.raiseBothArms) {
      screen = BodyTrainingScreen(
        action: RaiseBothArmsAction(
          difficulty: diff,
          targetCount: difficulty.targetReps,
        ),
        trainingActionMeta: action,
        difficultyMeta: difficulty,
        autoLevelUp: autoLevelUp, // 🆕
      );
    } else if (action.type == ActionType.elbowForward) {
      screen = BodyTrainingScreen(
        action: ElbowForwardAction(
          difficulty: diff,
          targetCount: difficulty.targetReps,
        ),
        trainingActionMeta: action,
        difficultyMeta: difficulty,
        autoLevelUp: autoLevelUp, // 🆕
      );
    } else if (action.type == ActionType.sitToStand) {
      screen = BodyTrainingScreen(
        action: SitToStandAction(
          difficulty: diff,
          targetCount: difficulty.targetReps,
        ),
        trainingActionMeta: action,
        difficultyMeta: difficulty,
        autoLevelUp: autoLevelUp, // 🆕
      );
    } else if (action.type == ActionType.lateralStep) {
      screen = BodyTrainingScreen(
        action: LateralStepAction(
          difficulty: diff,
          targetCount: difficulty.targetReps,
        ),
        trainingActionMeta: action,
        difficultyMeta: difficulty,
        autoLevelUp: autoLevelUp, // 🆕
      );
    } else {
      screen = TrainingScreen(
        action: action,
        difficulty: difficulty,
        autoLevelUp: autoLevelUp, // 🆕(原本沒帶,手部動作換過去會變回預設 true)
      );
    }

    if (!mounted) return;

    // 有 3D 示範的動作 → 先進示範頁;沒有的 → 直接進訓練
    final Widget destination = hasDemo3D(action.type)
        ? TrainingPreviewScreen(
            actionType: action.type,
            actionName: action.name,
            targetScreen: screen,
            difficultyLabel: difficulty.label,
            targetReps: difficulty.targetReps,
            description: action.description,
          )
        : screen;

    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => destination));
    //Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => screen));
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
    _aiSessionClock.stop();
    _aiTrajectoryCollector.reset();
    if (_recordingStarted && !_completionShown) {
      ScreenRecorderService.stopRecording().then((path) {
        if (path != null) {
          File(path).delete().catchError((e) => File(path));
        }
      });
    }
    VoiceService.stop();
    // 🖥️ 電視投放新增
    _socketSub?.cancel();
    _engine.imageNotifier.removeListener(_onImageUpdate);
    _rtcService.dispose();
    _remoteRenderer.dispose();
    _remoteState.dispose();
    _engine.poseNotifier.removeListener(_onPoseUpdate);
    _piCamera?.dispose(); // 🚀 樹莓派新增
    _piHand?.dispose(); // 🚀 樹莓派手部新增
    _handService.dispose(); // 🚀 樹莓派手部新增
    _engine.dispose();
    _levelUpRepsController.dispose(); // 🆕
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFFFFFFF),
          body: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildBody()),
                // 🖥️ 電視投放:顯示端讀 remote,控制端讀本機
                if (widget.isDisplay)
                  ValueListenableBuilder<RehabSessionState>(
                    valueListenable: _remoteState,
                    builder: (_, remote, __) => _buildRemoteCoachCard(remote),
                  )
                else
                  _buildCoachCard(),
                if (_usesTemplateAnalysis) _buildAiQualityCard(),
                if (widget.isDisplay)
                  ValueListenableBuilder<RehabSessionState>(
                    valueListenable: _remoteState,
                    builder: (_, remote, __) => _buildRemoteStatsBar(remote),
                  )
                else
                  _buildStatsBar(),
              ],
            ),
          ),
        ),
        if (_levelUpDialogShowing) _buildLevelUpOverlay(), // 🆕
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (!widget.isDisplay &&
                  (_clientService.isConnected ||
                      _serverService.isClientConnected)) {
                final msg = {'type': 'STOP'};
                if (_clientService.isConnected) {
                  _clientService.sendCommand(msg);
                } else {
                  _serverService.sendMessage(msg);
                }
              }
              Navigator.of(context).pop();
            },
            child: Container(
              width: 40,
              height: 40,
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
              width: 40,
              height: 40,
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
                color:
                    _isExternalCamera ? Colors.white : const Color(0xFF374151),
                size: 20,
              ),
            ),
          ),
          GestureDetector(
            onTap: _isSwitchingCameraUI ? null : _switchCamera, // 🆕 切換中直接不給按
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isSwitchingCameraUI
                    ? const Color(0xFFDDE0F0) // 🆕 切換中顏色變灰,視覺上明確表示不能按
                    : const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDE0F0)),
              ),
              child: _isSwitchingCameraUI
                  ? const SizedBox(
                      // 🆕 切換中顯示小圈圈,取代圖示
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF4A65FF)),
                    )
                  : const Icon(Icons.flip_camera_ios,
                      color: Color(0xFF374151), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // 🖥️ 電視投放新增:顯示端 → 顯示遠端傳來的畫面+骨架,不開相機
    if (widget.isDisplay) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            color: const Color(0xFF1A1D2E),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ValueListenableBuilder<Uint8List?>(
                  valueListenable: _engine.imageNotifier,
                  builder: (_, jpeg, __) {
                    if (jpeg == null) {
                      return const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF4A65FF)),
                      );
                    }
                    return Image.memory(jpeg,
                        gaplessPlayback: true, fit: BoxFit.cover);
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
              ],
            ),
          ),
        ),
      );
    }

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
                  return Image.memory(jpeg,
                      fit: BoxFit.cover, gaplessPlayback: true);
                },
              ),
              // 🚀 修正:身體骨架 painter 加上 sourceSize(來自 _piCamera.frameSize),
              // 讓骨架點位跟畫面顯示用的 BoxFit.cover 裁切/縮放對齊。
              ValueListenableBuilder<PoseData>(
                valueListenable: _engine.poseNotifier,
                builder: (_, data, __) {
                  return ValueListenableBuilder<Size?>(
                    valueListenable: _piCamera!.frameSize,
                    builder: (_, srcSize, __) {
                      return TweenAnimationBuilder<PoseData>(
                        tween: _PoseTween(end: data),
                        duration: const Duration(milliseconds: 40),
                        curve: Curves.easeOutCubic,
                        builder: (_, lerped, __) => CustomPaint(
                          painter: _SkeletonPainter(
                            lerped,
                            _scoreThreshold,
                            sourceSize: srcSize, // 🚀 新增
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              // 🚀 樹莓派手部骨架:一樣加上 sourceSize(來自 _piHand.frameSize),
              // 跟身體骨架用同一套 BoxFit.cover 換算,確保三者(畫面/身體/手部)貼合。
              ValueListenableBuilder<DetectionResult>(
                valueListenable: _piHand!.handResult,
                builder: (_, hand, __) {
                  if (!hand.handDetected || hand.landmarks.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return ValueListenableBuilder<Size?>(
                    valueListenable: _piHand!.frameSize,
                    builder: (_, srcSize, __) => CustomPaint(
                      painter: _PiHandSkeletonPainter(
                        hand.landmarks,
                        sourceSize: srcSize, // 🚀 新增
                      ),
                    ),
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
              // 🛠️ 2026-09-09：外接鏡頭也要保留選手 UI，
              // 否則 ReachAction 切到樹莓派後若尚未選手，update() 會永遠等待。
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
              // 🛠️ 外接鏡頭同樣保留下肢「患側 → 簡單/困難版」選擇。
              if (_waitingLegSelect)
                Container(
                  color: Colors.black.withValues(alpha: 0.65),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _buildLegSelectContent(),
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

    // ── 原本手機內建鏡頭邏輯,完全不變(不傳 sourceSize,行為不受影響) ──
    final cam = _engine.cameraController;
    if (!_engine.cameraReady.value || cam == null) {
      return const Center(
        child:
            CircularProgressIndicator(color: Color(0xFF00BCD4), strokeWidth: 3),
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
            // 🆕 選腳:站姿抬腳式 / 側跨步共用的「選患側 → 選簡單/困難版」畫面
            if (_waitingLegSelect)
              Container(
                color: Colors.black.withValues(alpha: 0.65),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _buildLegSelectContent(),
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

  // 🆕 選腳畫面內容:依「患側是否已選」分兩步顯示不同的按鈕組。
  //    寫在同一個 getter/method 裡,不用額外的狀態變數追蹤「第幾步」,
  //    完全靠 action 本身(LegRoleSelectable)的狀態算出來要顯示哪一步。
  List<Widget> _buildLegSelectContent() {
    final legAction = widget.action as LegRoleSelectable;

    if (!legAction.trainedLegSelected) {
      // 第一步:選患側
      return [
        const Text(
          '請選擇患側是哪一隻腳',
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
            _legButton('左腳', () {
              setState(() {
                legAction.selectTrainedLeg(isLeft: true);
                if (_usesTemplateAnalysis) {
                  _selectedAiTrainedSide = BodySide.left;
                  _aiTrajectoryCollector.reset();
                }
              });
            }),
            const SizedBox(width: 28),
            _legButton('右腳', () {
              setState(() {
                legAction.selectTrainedLeg(isLeft: false);
                if (_usesTemplateAnalysis) {
                  _selectedAiTrainedSide = BodySide.right;
                  _aiTrajectoryCollector.reset();
                }
              });
            }),
          ],
        ),
      ];
    }

    // 第二步:患側已選,選簡單版/困難版
    return [
      const Text(
        '請選擇訓練模式',
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
          _modeButton('簡單版\n患側動．好腳撐', () {
            setState(() {
              legAction.selectSimpleMode();
              _updateAiMovementSide(legAction);
              _feedback = '已選擇簡單版';
              _instruction = widget.action.initialHint;
            });
          }),
          const SizedBox(width: 20),
          _modeButton('困難版\n患側撐．好腳動', () {
            setState(() {
              legAction.selectHardMode();
              _updateAiMovementSide(legAction);
              _feedback = '已選擇困難版';
              _instruction = widget.action.initialHint;
            });
          }),
        ],
      ),
    ];
  }

  // 🆕 選腳按鈕(第一步用),樣式比照 _handButton
  Widget _legButton(String label, VoidCallback onTap) {
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
            const Icon(Icons.directions_walk, color: Colors.white, size: 42),
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

  // 🆕 簡單版/困難版按鈕(第二步用)
  Widget _modeButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        height: 130,
        padding: const EdgeInsets.symmetric(horizontal: 8),
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
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
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
                    style:
                        const TextStyle(color: Color(0xFF4A65FF), fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiQualityCard() {
    String value = '--';
    final result = _lastAiAnalysis;
    if (result?.valid == true) {
      value = '${_lastAiAnalysis!.overallScore!.round()} 分';
    }
    final deviations = result == null
        ? const <String>[]
        : BodyTemplateDeviationFormatter.describe(result);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '本次 AI 動作品質',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF1A1D2E),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (result?.unavailableReason != null) ...[
            const SizedBox(height: 4),
            Text(
              result!.unavailableReason!,
              style: const TextStyle(color: Color(0xFF8A8D9F), fontSize: 10),
            ),
          ],
          if (deviations.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              '主要差異',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            ...deviations.map(
              (message) => Text(
                '• $message',
                style: const TextStyle(
                  color: Color(0xFF8A8D9F),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _resetAiForSourceChange() {
    _aiTrajectoryCollector.reset();
    _lastAiAnalysis = null;
  }

  void _updateAiMovementSide(LegRoleSelectable action) {
    if (!_usesTemplateAnalysis || _selectedAiTrainedSide == null) return;
    final trainedSide = _selectedAiTrainedSide!;
    _selectedAiMovementSide = action.role == TrainingLegRole.moveTrainedLeg
        ? trainedSide
        : (trainedSide == BodySide.left ? BodySide.right : BodySide.left);
    _aiTrajectoryCollector.reset();
  }

  // 🖥️ 電視投放:顯示端教練卡,讀遠端傳來的 feedback/instruction
  Widget _buildRemoteCoachCard(RehabSessionState state) {
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
                  state.feedback,
                  style: const TextStyle(
                    color: Color(0xFF1A1D2E),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (state.instruction.isNotEmpty)
                  Text(
                    state.instruction,
                    style:
                        const TextStyle(color: Color(0xFF4A65FF), fontSize: 12),
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
          Expanded(child: _statCard('目前難度', widget.action.difficultyLabel)),
          const SizedBox(width: 12),
          _buildStopButton(),
        ],
      ),
    );
  }

// 🖥️ 電視投放:顯示端次數列,讀遠端傳來的 repCount
  Widget _buildRemoteStatsBar(RehabSessionState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(child: _statCard('完成次數', '${state.repCount}')),
          const SizedBox(width: 12),
          Expanded(child: _statCard('目前難度', widget.action.difficultyLabel)),
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
              style: const TextStyle(color: Color(0xFF8A8D9F), fontSize: 11)),
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

  // 🛠️ 修正:拿掉多餘的 Positioned.fill(Material 不是 Stack,
  // 這個 overlay 已經被包在最外層 build() 的 Stack 裡了,不需要再包一層)
  Widget _buildLevelUpOverlay() {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 10),
                Text(
                  _hasNextLevel ? '動作做得很棒！' : '已經是最高難度了！',
                  style: const TextStyle(
                    color: Color(0xFF1A1D2E),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _hasNextLevel ? '要挑戰下一階「$_nextLevelLabel」嗎？' : '再接再厲，繼續保持！',
                  style:
                      const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                if (_hasNextLevel) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '下一階要做幾下',
                        style: TextStyle(
                            color: Color(0xFF374151),
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 56,
                        child: TextField(
                          controller: _levelUpRepsController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1D2E)),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xFFDDE0F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xFF4A65FF)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text('下',
                          style: TextStyle(
                              color: Color(0xFF6B7280), fontSize: 13)),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        _hasNextLevel ? _confirmLevelUp : _declineLevelUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A65FF),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      _hasNextLevel ? '💪 挑戰下一階' : '🎉 完成訓練',
                      style: const TextStyle(
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
                    onPressed: _declineLevelUp,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFDDE0F0)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      '結束訓練',
                      style: TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
  // 🚀 新增:原始畫面(樹莓派 JPEG)的實際尺寸。傳 null 時維持原本行為
  // (直接用容器尺寸換算),手機鏡頭(CameraPreview)場景不受影響。
  final Size? sourceSize;

  _SkeletonPainter(this.data, this.threshold, {this.sourceSize});

  bool _valid(Offset p) =>
      p.dx > 0.02 && p.dx < 0.98 && p.dy > 0.02 && p.dy < 0.98;

  // 🚀 新增:算出跟 Image.memory(fit: BoxFit.cover) 一致的縮放倍率
  // 與置中裁切偏移量,邏輯跟 hand_overlay_widget.dart 的修正相同。
  ({double scale, double dx, double dy}) _coverTransform(Size canvasSize) {
    final src = sourceSize;
    if (src == null || src.width <= 0 || src.height <= 0) {
      return (scale: 1.0, dx: 0.0, dy: 0.0);
    }
    final scaleX = canvasSize.width / src.width;
    final scaleY = canvasSize.height / src.height;
    final scale = scaleX > scaleY ? scaleX : scaleY; // cover: 取較大值
    final scaledW = src.width * scale;
    final scaledH = src.height * scale;
    final dx = (canvasSize.width - scaledW) / 2;
    final dy = (canvasSize.height - scaledH) / 2;
    return (scale: scale, dx: dx, dy: dy);
  }

  Offset _map(Offset p, Size canvasSize) {
    final t = _coverTransform(canvasSize);
    final srcW = sourceSize?.width ?? canvasSize.width;
    final srcH = sourceSize?.height ?? canvasSize.height;
    return Offset(
      p.dx * srcW * t.scale + t.dx,
      p.dy * srcH * t.scale + t.dy,
    );
  }

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
      canvas.drawLine(_map(pa, size), _map(pb, size), bone);
    }
    for (int i = 0; i < 17 && i < data.keypoints.length; i++) {
      if (i >= data.scores.length || data.scores[i] < threshold) continue;
      final p = data.keypoints[i];
      if (!_valid(p)) continue;
      canvas.drawCircle(_map(p, size), 5, joint);
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) => true;
}

// 🚀 樹莓派手部骨架 painter
// 🚀 修正:加上 sourceSize,套用跟 _SkeletonPainter / HandOverlayPainter
// 相同的 BoxFit.cover 換算邏輯,確保跟畫面顯示、跟身體骨架三者對齊。
// 若跑起來發現方向不對(左右相反或上下顛倒),把 map() 裡的
// lm.x 改成 (1 - lm.x) 或 lm.y 改成 (1 - lm.y) 即可修正。
class _PiHandSkeletonPainter extends CustomPainter {
  final List<Landmark> landmarks;
  final Size? sourceSize; // 🚀 新增

  _PiHandSkeletonPainter(this.landmarks, {this.sourceSize});

  static const _connections = [
    [0, 1], [1, 2], [2, 3], [3, 4],
    [0, 5], [5, 6], [6, 7], [7, 8],
    [0, 9], [9, 10], [10, 11], [11, 12],
    [0, 13], [13, 14], [14, 15], [15, 16],
    [0, 17], [17, 18], [18, 19], [19, 20],
  ];

  ({double scale, double dx, double dy}) _coverTransform(Size canvasSize) {
    final src = sourceSize;
    if (src == null || src.width <= 0 || src.height <= 0) {
      return (scale: 1.0, dx: 0.0, dy: 0.0);
    }
    final scaleX = canvasSize.width / src.width;
    final scaleY = canvasSize.height / src.height;
    final scale = scaleX > scaleY ? scaleX : scaleY;
    final scaledW = src.width * scale;
    final scaledH = src.height * scale;
    final dx = (canvasSize.width - scaledW) / 2;
    final dy = (canvasSize.height - scaledH) / 2;
    return (scale: scale, dx: dx, dy: dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final t = _coverTransform(size);
    final srcW = sourceSize?.width ?? size.width;
    final srcH = sourceSize?.height ?? size.height;

    Offset map(Landmark lm) => Offset(
          lm.x * srcW * t.scale + t.dx,
          lm.y * srcH * t.scale + t.dy,
        );

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
      canvas.drawLine(
          map(landmarks[conn[0]]), map(landmarks[conn[1]]), linePaint);
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
  final bool? autoLevelUp; // 🆕
  const _CompletionResult._(
      this.kind, this.action, this.difficulty, this.autoLevelUp);
  factory _CompletionResult.retry() =>
      const _CompletionResult._(_CompletionKind.retry, null, null, null);
  factory _CompletionResult.home() =>
      const _CompletionResult._(_CompletionKind.home, null, null, null);
  factory _CompletionResult.startNew(
          TrainingAction a, DifficultyOption d, bool autoLevelUp) => // 🆕
      _CompletionResult._(_CompletionKind.startNew, a, d, autoLevelUp);
}
