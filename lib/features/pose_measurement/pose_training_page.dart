import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/assignable_exercise.dart';
import 'joint_angle_calculator.dart';
import 'models/joint_angle_frame.dart';
import 'models/pose_frame.dart';
import 'pose_camera_controller.dart';
import 'pose_camera_view.dart';

/// Measurement only: no evaluation, repetition counting, recording or upload.
/// An injected controller is owned and disposed by this page as well.
class PoseTrainingPage extends StatefulWidget {
  const PoseTrainingPage({
    super.key,
    required this.exercise,
    this.controller,
    this.previewBuilder,
  });

  final AssignableExercise exercise;
  final PoseCameraController? controller;
  final PoseNativePreviewBuilder? previewBuilder;

  @override
  State<PoseTrainingPage> createState() => _PoseTrainingPageState();
}

class _PoseTrainingPageState extends State<PoseTrainingPage>
    with WidgetsBindingObserver {
  late final PoseCameraController _controller;
  bool _foreground = true;
  bool _routeVisible = true;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? PoseCameraController();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    if (widget.previewBuilder == null &&
        (kIsWeb || defaultTargetPlatform != TargetPlatform.android)) {
      _controller.markUnavailable();
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
    _syncActive();
  }

  void _syncActive() => _controller.setActive(_foreground && _routeVisible);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
                    _AngleReadout(controller: _controller),
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
            TextButton(
              onPressed: openAppSettings,
              child: const Text('開啟系統設定'),
            ),
        ],
      ),
    );
  }
}

class _AngleReadout extends StatelessWidget {
  const _AngleReadout({required this.controller});

  final PoseCameraController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PoseFrame?>(
      valueListenable: controller.frame,
      builder: (_, frame, __) {
        // World coordinates only. The painter and its mirrored display
        // coordinates are deliberately never passed into this calculator.
        final angles =
            frame == null ? null : JointAngleCalculator().calculate(frame);
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
                      '${joint.label}：${angles?[joint]?.toStringAsFixed(0) ?? '--'}${angles?[joint] == null ? '' : '°'}',
                      key: Key('pose-angle-${joint.name}'),
                      style: const TextStyle(color: Color(0xFF1A1D2E)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '請與鏡頭保持距離，讓頭部與雙腳入鏡。\n左右以您自身為準；關節不清楚時顯示 --。\n此頁僅量測幾何角度，不判定動作正確性、不記錄結果。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF667085), fontSize: 11),
              ),
              if (frame != null)
                Text(
                  '本機推論：${frame.inferenceMs.toStringAsFixed(0)} 毫秒',
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
