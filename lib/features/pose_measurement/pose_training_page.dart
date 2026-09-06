import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/assignable_exercise.dart';
import '../../models/custom_rehab_exercise.dart';
import 'evaluation/pose_evaluation_engine.dart';
import 'evaluation/pose_evaluation_result.dart';
import 'evaluation/pose_evaluation_session.dart';
import 'evaluation/pose_measurement_rule.dart';
import 'evaluation/pose_measurement_rule_resolver.dart';
import 'models/joint_angle_frame.dart';
import 'pose_camera_controller.dart';
import 'pose_camera_view.dart';
import 'repositories/training_result_repository.dart';
import 'repositories/training_result_repository_selection.dart';
import 'training/pose_training_session_controller.dart';
import 'training/training_progress_panel.dart';
import 'training/training_session_state_machine.dart';

@visibleForTesting
TrainingSessionConfig trainingSessionConfigFor({
  required CustomRehabExercise? customExercise,
  required bool hasRules,
}) {
  final custom = customExercise;
  return custom == null
      ? TrainingSessionConfig(
          targetReps: 5,
          targetSets: 1,
          holdDuration: const Duration(milliseconds: 1500),
          autoCountEnabled: hasRules,
        )
      : TrainingSessionConfig(
          targetReps: custom.repetitions,
          targetSets: custom.sets,
          holdDuration: Duration(
            milliseconds: (custom.holdSeconds * 1000).round(),
          ),
          autoCountEnabled: hasRules,
        );
}

/// An injected controller is owned and disposed by this page as well.
class PoseTrainingPage extends StatefulWidget {
  const PoseTrainingPage({
    super.key,
    required this.exercise,
    this.customExercise,
    this.controller,
    this.previewBuilder,
    this.ruleResolver = const PoseMeasurementRuleResolver(),
    this.resultRepository,
  });

  final AssignableExercise exercise;
  final CustomRehabExercise? customExercise;
  final PoseCameraController? controller;
  final PoseNativePreviewBuilder? previewBuilder;
  final PoseMeasurementRuleResolver ruleResolver;
  final TrainingResultRepository? resultRepository;

  @override
  State<PoseTrainingPage> createState() => _PoseTrainingPageState();
}

class _PoseTrainingPageState extends State<PoseTrainingPage>
    with WidgetsBindingObserver {
  late final PoseCameraController _controller;
  late List<PoseMeasurementRule> _rules;
  late PoseEvaluationSession _evaluationSession;
  late PoseTrainingSessionController _trainingSession;
  bool _foreground = true;
  bool _routeVisible = true;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? PoseCameraController();
    _createEvaluationSession();
    _controller.state.addListener(_onCameraState);
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    if (widget.previewBuilder == null &&
        (kIsWeb || defaultTargetPlatform != TargetPlatform.android)) {
      _controller.markUnavailable();
    }
  }

  void _createEvaluationSession() {
    _rules = widget.ruleResolver.resolve(
      widget.exercise,
      customExercise: widget.customExercise,
    );
    _evaluationSession = PoseEvaluationSession(
      camera: _controller,
      rules: _rules,
    );
    final config = trainingSessionConfigFor(
      customExercise: widget.customExercise,
      hasRules: _rules.isNotEmpty,
    );
    _trainingSession = PoseTrainingSessionController(
      evaluation: _evaluationSession.snapshot,
      exercise: widget.exercise,
      repository: widget.resultRepository ?? trainingResultRepository,
      config: config,
    );
  }

  @override
  void didUpdateWidget(PoseTrainingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.identityKey != widget.exercise.identityKey ||
        oldWidget.customExercise != widget.customExercise ||
        oldWidget.ruleResolver != widget.ruleResolver ||
        oldWidget.resultRepository != widget.resultRepository) {
      _trainingSession.dispose();
      _evaluationSession.dispose();
      _createEvaluationSession();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ModalRoute's current-state dependency also changes when another route
    // covers this page, without installing a global navigation observer.
    _routeVisible = ModalRoute.isCurrentOf(context) ?? true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncActive();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _trainingSession.reset();
    _syncActive();
  }

  void _syncActive() {
    final active = _foreground && _routeVisible;
    if (!active) _trainingSession.reset();
    _controller.setActive(active);
  }

  void _onCameraState() {
    final state = _controller.state.value;
    if (state == PoseCameraState.paused ||
        state == PoseCameraState.unavailable ||
        state == PoseCameraState.error ||
        state == PoseCameraState.permissionDenied ||
        state == PoseCameraState.permissionPermanentlyDenied) {
      _trainingSession.reset();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.state.removeListener(_onCameraState);
    _trainingSession.dispose();
    _evaluationSession.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('姿勢量測'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D2E),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                widget.exercise.name,
                style: const TextStyle(
                  color: Color(0xFF1A1D2E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: PoseCameraView(
                    controller: _controller,
                    previewBuilder: widget.previewBuilder,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ValueListenableBuilder<PoseCameraState>(
                      valueListenable: _controller.state,
                      builder: (_, state, __) => _buildStatus(state),
                    ),
                    TrainingProgressPanel(controller: _trainingSession),
                    _AngleAndEvaluationReadout(
                      session: _evaluationSession,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatus(PoseCameraState state) {
    final retry = state == PoseCameraState.permissionDenied ||
        state == PoseCameraState.error ||
        state == PoseCameraState.unavailable;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          Text(
            state.label,
            key: const Key('pose-camera-status'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF364152)),
          ),
          if (retry)
            TextButton(
              onPressed: _controller.retry,
              child: const Text('重試'),
            ),
          if (state == PoseCameraState.permissionPermanentlyDenied)
            const TextButton(
              onPressed: openAppSettings,
              child: Text('開啟系統設定'),
            ),
        ],
      ),
    );
  }
}

class _AngleAndEvaluationReadout extends StatelessWidget {
  const _AngleAndEvaluationReadout({required this.session});

  final PoseEvaluationSession session;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PoseEvaluationSnapshot>(
      valueListenable: session.snapshot,
      builder: (_, snapshot, __) {
        final angles = snapshot.measurements;
        final evaluation = snapshot.evaluation;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  for (final joint in JointMeasurementType.values)
                    Text(
                      '${joint.label}：${angles[joint]?.toStringAsFixed(0) ?? '--'}${angles[joint] == null ? '' : '°'}',
                      key: Key('pose-angle-${joint.name}'),
                      style: const TextStyle(color: Color(0xFF1A1D2E)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _OverallEvaluationCard(
                status: evaluation.presentedOverallStatus,
              ),
              if (evaluation.raw.rules.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final result in evaluation.raw.rules)
                  _RuleEvaluationCard(result: result),
              ],
              const SizedBox(height: 8),
              const Text(
                '請與鏡頭保持距離，讓頭部與雙腳入鏡。\n左右以您自身為準；關節不清楚時顯示 --。\n本頁依幾何角度完成保持、次數與組數訓練；分數僅代表完成度，不代表醫療診斷。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF667085), fontSize: 11),
              ),
              if (snapshot.inferenceMs > 0)
                Text(
                  '本機推論：${snapshot.inferenceMs.toStringAsFixed(0)} 毫秒',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OverallEvaluationCard extends StatelessWidget {
  const _OverallEvaluationCard({required this.status});

  final PoseOverallEvaluationStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (status) {
      PoseOverallEvaluationStatus.correct => (
          Icons.check_circle,
          const Color(0xFF2E7D32),
          '姿勢正確'
        ),
      PoseOverallEvaluationStatus.needsAdjustment => (
          Icons.tune,
          const Color(0xFFC2410C),
          '請調整姿勢'
        ),
      PoseOverallEvaluationStatus.unavailable => (
          Icons.visibility_off_outlined,
          const Color(0xFF667085),
          '尚未偵測完整姿勢'
        ),
      PoseOverallEvaluationStatus.noRules => (
          Icons.info_outline,
          const Color(0xFF667085),
          '此動作尚未設定姿勢評估規則'
        ),
    };
    return Container(
      key: const Key('pose-overall-evaluation'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              key: Key('pose-overall-${status.name}'),
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleEvaluationCard extends StatelessWidget {
  const _RuleEvaluationCard({required this.result});

  final PoseRuleEvaluationResult result;

  @override
  Widget build(BuildContext context) {
    final rule = result.rule;
    final passed = result.status == PoseRuleEvaluationStatus.pass;
    final unavailable = result.status == PoseRuleEvaluationStatus.unavailable;
    final color = passed
        ? const Color(0xFF2E7D32)
        : unavailable
            ? const Color(0xFF667085)
            : const Color(0xFFC2410C);
    String degrees(double value) => '${value.toStringAsFixed(0)}°';
    return Container(
      key: Key('pose-rule-${rule.measurement.name}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rule.measurement.evaluationLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            '目前：${result.currentAngleDegrees == null ? '--' : degrees(result.currentAngleDegrees!)}　'
            '目標：${degrees(rule.targetAngleDegrees)}',
          ),
          Text(
            '容許：${degrees(result.lowerBound)}–${degrees(result.upperBound)}',
            style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                passed
                    ? Icons.check
                    : unavailable
                        ? Icons.remove
                        : Icons.tune,
                color: color,
                size: 17,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  result.feedback,
                  key: Key(
                    'pose-rule-feedback-${rule.measurement.name}-${result.status.name}',
                  ),
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
