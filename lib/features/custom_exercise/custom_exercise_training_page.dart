import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../models/custom_rehab_exercise.dart';
import '../../models/pose_data.dart';
import '../../services/body_pose_engine.dart';
import '../pose_measurement/repositories/training_result_repository.dart';
import '../pose_measurement/repositories/training_result_repository_selection.dart';
import 'training/custom_exercise_pose_source.dart';
import 'training/custom_exercise_training_controller.dart';

class CustomExerciseTrainingPage extends StatefulWidget {
  const CustomExerciseTrainingPage({
    super.key,
    required this.exercise,
    this.poseSource,
    this.trainingController,
    this.resultRepository,
  });

  final CustomRehabExercise exercise;
  final CustomExercisePoseSource? poseSource;
  final CustomExerciseTrainingController? trainingController;
  final TrainingResultRepository? resultRepository;

  @override
  State<CustomExerciseTrainingPage> createState() =>
      _CustomExerciseTrainingPageState();
}

class _CustomExerciseTrainingPageState extends State<CustomExerciseTrainingPage>
    with WidgetsBindingObserver {
  late final CustomExercisePoseSource _source;
  late final CustomExerciseTrainingController _training;
  final Stopwatch _stopwatch = Stopwatch();
  bool _initializing = true;
  bool _switchingCamera = false;
  bool _pausedByUser = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _source = widget.poseSource ?? BodyPoseCustomExerciseSource();
    _training = widget.trainingController ??
        CustomExerciseTrainingController(
          exercise: widget.exercise,
          repository: widget.resultRepository ?? trainingResultRepository,
        );
    _source.pose.addListener(_onPose);
    WidgetsBinding.instance.addObserver(this);
    _stopwatch.start();
    unawaited(_initializeCamera());
  }

  Future<void> _initializeCamera() async {
    try {
      await _source.initialize();
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _cameraError = null;
      });
      _training.markReady();
    } on Object {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _cameraError = '相機或 RTMPose 初始化失敗，請確認相機權限後重試';
      });
    }
  }

  void _onPose() {
    if (_initializing || _switchingCamera || _cameraError != null) return;
    _training.processPose(_source.pose.value, _stopwatch.elapsed);
  }

  Future<void> _switchCamera() async {
    if (_switchingCamera ||
        _initializing ||
        _pausedByUser ||
        _training.snapshot.isCompleted) {
      return;
    }
    setState(() => _switchingCamera = true);
    _training.beginCameraSwitch();
    var success = false;
    try {
      await _source.switchCamera();
      success = true;
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('鏡頭切換失敗，請稍後再試')),
        );
      }
    } finally {
      _training.finishCameraSwitch(success: success);
      if (mounted) setState(() => _switchingCamera = false);
    }
  }

  Future<void> _retryCamera() async {
    if (_initializing) return;
    setState(() {
      _initializing = true;
      _cameraError = null;
    });
    await _initializeCamera();
  }

  Future<void> _togglePause() async {
    final paused =
        _training.snapshot.phase == CustomExerciseTrainingPhase.paused;
    if (paused) {
      try {
        await _source.resume();
        _training.resume();
        if (mounted) setState(() => _pausedByUser = false);
      } on Object {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('相機恢復失敗，請重試')),
          );
        }
      }
    } else {
      _training.pause();
      await _source.pause();
      if (mounted) setState(() => _pausedByUser = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_pausedByUser) return;
      unawaited(_source.resume().then((_) => _training.resume()));
      return;
    }
    _training.pause();
    unawaited(_source.pause());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _source.pose.removeListener(_onPose);
    _stopwatch.stop();
    _training.dispose();
    unawaited(_source.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(widget.exercise.name),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D2E),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: ColoredBox(
                    color: Colors.black,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildCameraPreview(),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: IconButton.filledTonal(
                            key: const Key('custom-training-switch-camera'),
                            onPressed: _switchingCamera ||
                                    _initializing ||
                                    _pausedByUser
                                ? null
                                : _switchCamera,
                            tooltip: '切換前後鏡頭',
                            icon: _switchingCamera
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.cameraswitch_rounded),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          top: 12,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Text(
                                _source.isFrontCamera ? '前鏡頭' : '後鏡頭',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: AnimatedBuilder(
                  animation: _training,
                  builder: (_, __) => _TrainingReadout(
                    snapshot: _training.snapshot,
                    onPause: _togglePause,
                    onRetrySubmission: _training.retrySubmission,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_initializing || _switchingCamera) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white, size: 42),
              const SizedBox(height: 12),
              Text(
                _cameraError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _retryCamera, child: const Text('重試')),
            ],
          ),
        ),
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: _source.cameraReady,
      builder: (_, ready, __) {
        final camera = _source.cameraController;
        if (!ready || camera == null || !camera.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(camera),
            ValueListenableBuilder<PoseData>(
              valueListenable: _source.pose,
              builder: (_, pose, __) => CustomPaint(
                painter: _CustomRtmPoseSkeletonPainter(pose),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TrainingReadout extends StatelessWidget {
  const _TrainingReadout({
    required this.snapshot,
    required this.onPause,
    required this.onRetrySubmission,
  });

  final CustomExerciseTrainingSnapshot snapshot;
  final VoidCallback onPause;
  final VoidCallback onRetrySubmission;

  @override
  Widget build(BuildContext context) {
    final paused = snapshot.phase == CustomExerciseTrainingPhase.paused;
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                Text('第 ${snapshot.currentRep} / ${snapshot.targetReps} 次'),
                Text('第 ${snapshot.currentSet} / ${snapshot.targetSets} 組'),
                Text(
                  '姿勢 ${snapshot.currentKeyframeIndex + 1} / '
                  '${snapshot.keyframeCount}',
                ),
                Text('符合度 ${snapshot.matchScore.toStringAsFixed(0)}%'),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              key: const Key('custom-training-keyframe-progress'),
              value: snapshot.keyframeCount == 0
                  ? 0
                  : (snapshot.currentKeyframeIndex + 1) /
                      snapshot.keyframeCount,
              minHeight: 7,
            ),
            if (snapshot.phase == CustomExerciseTrainingPhase.holding) ...[
              const SizedBox(height: 10),
              Text(
                '姿勢正確，保持中… '
                '${(snapshot.holdElapsed.inMilliseconds / 1000).toStringAsFixed(1)} / '
                '${(snapshot.holdDuration.inMilliseconds / 1000).toStringAsFixed(1)} 秒',
              ),
            ],
            if (snapshot.phase == CustomExerciseTrainingPhase.resting) ...[
              const SizedBox(height: 10),
              Text(
                '休息中… '
                '${(snapshot.restRemaining.inMilliseconds / 1000).toStringAsFixed(1)} 秒',
              ),
            ],
            const SizedBox(height: 12),
            Text(
              snapshot.feedback,
              key: const Key('custom-training-feedback'),
              style: TextStyle(
                color: snapshot.isCompleted
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF1F2937),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (snapshot.submissionStatus ==
                CustomExerciseResultSubmissionStatus.failed) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onRetrySubmission,
                child: const Text('紀錄儲存失敗，點此重試'),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('custom-training-pause'),
                    onPressed: snapshot.isCompleted ? null : onPause,
                    icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                    label: Text(paused ? '繼續' : '暫停'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.stop),
                    label: const Text('結束訓練'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'RTMPose 以關節方向與彎曲角度依序比對治療師 Keyframes。'
              '請讓肩、髖、手腳完整入鏡；分數僅代表動作符合度。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF667085), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomRtmPoseSkeletonPainter extends CustomPainter {
  const _CustomRtmPoseSkeletonPainter(this.pose);

  final PoseData pose;

  static const _connections = <(int, int)>[
    (5, 6),
    (5, 7),
    (7, 9),
    (6, 8),
    (8, 10),
    (5, 11),
    (6, 12),
    (11, 12),
    (11, 13),
    (13, 15),
    (12, 14),
    (14, 16),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bone = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.85)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final joint = Paint()..color = const Color(0xFF00E5FF);
    Offset map(Offset point) =>
        Offset(point.dx * size.width, point.dy * size.height);
    bool valid(int index) =>
        index < pose.keypoints.length &&
        index < pose.scores.length &&
        pose.scores[index] >= BodyPoseEngine.scoreThreshold &&
        pose.keypoints[index].dx.isFinite &&
        pose.keypoints[index].dy.isFinite;

    for (final (start, end) in _connections) {
      if (valid(start) && valid(end)) {
        canvas.drawLine(
          map(pose.keypoints[start]),
          map(pose.keypoints[end]),
          bone,
        );
      }
    }
    for (var index = 5; index <= 16; index++) {
      if (valid(index)) {
        canvas.drawCircle(map(pose.keypoints[index]), 5, joint);
      }
    }
  }

  @override
  bool shouldRepaint(_CustomRtmPoseSkeletonPainter oldDelegate) =>
      oldDelegate.pose != pose;
}
