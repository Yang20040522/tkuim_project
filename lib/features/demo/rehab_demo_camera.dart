class RehabDemoCamera {
  const RehabDemoCamera({
    required this.cameraOrbit,
    required this.cameraTarget,
    required this.fieldOfView,
    this.minCameraOrbit,
  });

  final String cameraOrbit;
  final String cameraTarget;
  final String fieldOfView;
  final String? minCameraOrbit;
}

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
