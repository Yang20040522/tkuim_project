import 'package:flutter_body/features/demo/rehab_demo_camera.dart';
import 'package:flutter_body/features/history/network_video_playback_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TV uses the verified camera for every hand-focused GLB', () {
    const models = {
      'assets/models/forearm_supination.glb',
      'assets/models/lateral_pinch.glb',
      'assets/models/wrist_extension.glb',
      'assets/models/turn_Right_hand.glb',
      'assets/models/turn_Left_hand.glb',
    };
    expect(kRehabDemoCameras.keys, containsAll(models));
    for (final model in models) {
      final camera = rehabDemoCameraFor(model);
      expect(camera, isNotNull, reason: model);
      expect(camera!.cameraOrbit, isNotEmpty);
      expect(camera.cameraTarget, isNotEmpty);
      expect(camera.fieldOfView, isNotEmpty);
    }
  });

  test('remote video construction retains authenticated headers', () {
    const screen = NetworkVideoPlaybackScreen(
      videoUrl: 'https://example.test/api/training-history/7/video',
      title: '訓練影片',
      httpHeaders: {
        'X-User-Id': '42',
        'X-Custom-Exercise-Token': 'token',
      },
    );
    expect(screen.videoUrl, endsWith('/7/video'));
    expect(screen.httpHeaders['X-User-Id'], '42');
    expect(screen.httpHeaders['X-Custom-Exercise-Token'], 'token');
  });
}
