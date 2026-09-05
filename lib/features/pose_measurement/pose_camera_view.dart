import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'models/pose_frame.dart';
import 'pose_camera_controller.dart';
import 'pose_skeleton_painter.dart';

typedef PoseNativePreviewBuilder = Widget Function(
  BuildContext context,
  ValueChanged<int> onPlatformViewCreated,
);

/// Camera preview is stable across all landmark updates. Only the transparent
/// Flutter overlay repaints; the native view retains camera ownership.
class PoseCameraView extends StatelessWidget {
  const PoseCameraView({
    super.key,
    required this.controller,
    this.previewBuilder,
  });

  final PoseCameraController controller;
  final PoseNativePreviewBuilder? previewBuilder;

  @override
  Widget build(BuildContext context) {
    final preview = previewBuilder != null
        ? previewBuilder!(context, controller.attach)
        : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? AndroidView(
                key: const Key('pose-native-camera'),
                viewType: 'com.rehabassist/pose_measurement/preview',
                onPlatformViewCreated: controller.attach,
              )
            : const Center(child: Text('姿勢量測目前僅支援 Android 裝置'));
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          preview,
          IgnorePointer(
            child: RepaintBoundary(
              child: ValueListenableBuilder<PoseFrame?>(
                valueListenable: controller.frame,
                builder: (_, frame, __) => CustomPaint(
                  key: const Key('pose-skeleton-overlay'),
                  painter: PoseSkeletonPainter(frame: frame),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
