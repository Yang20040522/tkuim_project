import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

/// Fixed camera values measured from the GLB skeletons and verified across the
/// full animation in a 360 x 380 model-viewer viewport.
class RehabDemoCamera {
  final String cameraOrbit;
  final String cameraTarget;
  final String fieldOfView;
  final String? minCameraOrbit;

  const RehabDemoCamera({
    required this.cameraOrbit,
    required this.cameraTarget,
    required this.fieldOfView,
    this.minCameraOrbit,
  });
}

/// Cameras are keyed by model because the GLBs use different scales, active
/// hands, and animation ranges. Models absent from this map keep their native
/// full-body framing.
const Map<String, RehabDemoCamera> kRehabDemoCameras = {
  'assets/models/forearm_supination.glb': RehabDemoCamera(
    cameraOrbit: '-45deg 75deg 2.5m',
    cameraTarget: '0.70m 4.70m 1.95m',
    fieldOfView: '25deg',
    minCameraOrbit: 'auto auto 0m',
  ),
  'assets/models/lateral_pinch.glb': RehabDemoCamera(
    cameraOrbit: '-55deg 75deg 2.1m',
    cameraTarget: '0.56m 4.63m 1.91m',
    fieldOfView: '25deg',
    minCameraOrbit: 'auto auto 0m',
  ),
  'assets/models/wrist_extension.glb': RehabDemoCamera(
    cameraOrbit: '-55deg 75deg 2.2m',
    cameraTarget: '0.64m 4.65m 1.93m',
    fieldOfView: '25deg',
    minCameraOrbit: 'auto auto 0m',
  ),
  'assets/models/turn_Right_hand.glb': RehabDemoCamera(
    cameraOrbit: '0deg 78deg 2.8m',
    cameraTarget: '0.34m 1.40m 0.30m',
    fieldOfView: '28deg',
    minCameraOrbit: 'auto auto 0m',
  ),
  'assets/models/turn_Left_hand.glb': RehabDemoCamera(
    cameraOrbit: '0deg 78deg 2.8m',
    cameraTarget: '-0.24m 1.42m 0.32m',
    fieldOfView: '28deg',
    minCameraOrbit: 'auto auto 0m',
  ),
};

RehabDemoCamera? rehabDemoCameraFor(String modelSrc) =>
    kRehabDemoCameras[modelSrc];

/// Shared viewer used by both training preview and the demo library. Keeping
/// auto rotation disabled here prevents either entry point from drifting.
class RehabDemoModelViewer extends StatelessWidget {
  final String src;
  final String alt;
  final Color backgroundColor;

  const RehabDemoModelViewer({
    super.key,
    required this.src,
    required this.alt,
    this.backgroundColor = const Color(0xFF1A1D2E),
  });

  @override
  Widget build(BuildContext context) {
    final camera = rehabDemoCameraFor(src);

    return ModelViewer(
      key: ValueKey(src),
      src: src,
      alt: alt,
      autoRotate: false,
      autoPlay: true,
      cameraControls: true,
      cameraOrbit: camera?.cameraOrbit,
      cameraTarget: camera?.cameraTarget,
      fieldOfView: camera?.fieldOfView,
      minCameraOrbit: camera?.minCameraOrbit,
      backgroundColor: backgroundColor,
    );
  }
}
