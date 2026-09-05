import 'package:flutter_body/features/pose_measurement/models/pose_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all 33 official anatomical indices are stable', () {
    expect(PoseLandmarkType.values.length, 33);
    expect(PoseLandmarkType.nose.index, 0);
    expect(PoseLandmarkType.leftShoulder.index, 11);
    expect(PoseLandmarkType.rightShoulder.index, 12);
    expect(PoseLandmarkType.leftElbow.index, 13);
    expect(PoseLandmarkType.rightElbow.index, 14);
    expect(PoseLandmarkType.leftWrist.index, 15);
    expect(PoseLandmarkType.rightWrist.index, 16);
    expect(PoseLandmarkType.leftHip.index, 23);
    expect(PoseLandmarkType.rightHip.index, 24);
    expect(PoseLandmarkType.leftKnee.index, 25);
    expect(PoseLandmarkType.rightKnee.index, 26);
    expect(PoseLandmarkType.leftAnkle.index, 27);
    expect(PoseLandmarkType.rightAnkle.index, 28);
    expect(PoseLandmarkType.rightFootIndex.index, 32);
  });

  test('native result retains normalized and world coordinates independently',
      () {
    final values = List.generate(
      33,
      (index) => <String, Object>{
        'x': index / 33,
        'y': 0.5,
        'z': -0.2,
        'visibility': 0.9,
        'presence': 0.8,
      },
    );
    final world = List.generate(
      33,
      (index) => <String, Object>{
        'x': index.toDouble(),
        'y': -2,
        'z': 3.5,
        'visibility': 0.95,
      },
    );
    final frame = PoseFrame.fromPlatform(<dynamic, dynamic>{
      'type': 'frame',
      'timestampMs': 123,
      'landmarks': values,
      'worldLandmarks': world,
      'inferenceMs': 20,
      'geometry': geometryMap(),
    });
    expect(frame.timestampMs, 123);
    expect(frame.inferenceMs, 20.0);
    expect(frame.hasPose, isTrue);
    expect(frame.landmarks.length, 33);
    expect(frame.worldLandmarks.length, 33);
    expect(frame.landmarks[PoseLandmarkType.leftElbow]!.x, 13 / 33);
    expect(frame.worldLandmarks[PoseLandmarkType.leftElbow]!.x, 13);
    expect(frame.worldLandmarks[PoseLandmarkType.leftElbow]!.presence, isNull);
    expect(frame.worldLandmarks[PoseLandmarkType.leftElbow]!.isReliable(), isTrue);
    expect(frame.geometry!.revision, 2);
    expect(() => frame.landmarks.clear(), throwsUnsupportedError);
    expect(() => frame.worldLandmarks.clear(), throwsUnsupportedError);
    expect(() => frame.geometry!.matrix.clear(), throwsUnsupportedError);
  });

  test('invalid landmarks do not shift later anatomical identities', () {
    final points = List<Object?>.filled(33, null);
    points[12] = {'x': 0.8, 'y': 0.5, 'z': 0, 'visibility': 0.1};
    points[13] = {'x': 0.2, 'y': 0.5};
    points[14] = {'x': 0.9, 'y': 0.6, 'z': 0, 'presence': 0.8};
    final frame = PoseFrame.fromPlatform({
      'timestampMs': 1,
      'landmarks': points,
      'worldLandmarks': [],
    });
    expect(frame.hasPose, isTrue);
    expect(frame.landmarks[PoseLandmarkType.rightShoulder]!.x, 0.8);
    expect(frame.landmarks[PoseLandmarkType.leftElbow], isNull);
    expect(frame.landmarks[PoseLandmarkType.rightElbow]!.x, 0.9);
    expect(frame.geometry, isNull);
  });

  test('no pose and low confidence pose are different states', () {
    expect(PoseFrame(timestampMs: 1).hasPose, isFalse);
    final partial = PoseFrame(timestampMs: 2, landmarks: const {
      PoseLandmarkType.leftElbow:
          PoseLandmark(x: 0.2, y: 0.5, z: 0, visibility: 0.1),
    });
    expect(partial.hasPose, isTrue);
    expect(partial.landmarks.values.single.isReliable(), isFalse);
  });

  test('missing and malformed confidence is never assumed reliable', () {
    const unknown = PoseLandmark(x: 0, y: 0, z: 0);
    expect(unknown.confidence, isNull);
    expect(unknown.isReliable(), isFalse);
    const minimum = PoseLandmark(
      x: 0,
      y: 0,
      z: 0,
      visibility: 0.99,
      presence: 0.2,
    );
    expect(minimum.confidence, 0.2);
    expect(minimum.isReliable(), isFalse);
    final malformed = PoseLandmark.tryFromPlatform({
      'x': 0,
      'y': 0,
      'z': 0,
      'visibility': 0.9,
      'presence': 'unknown',
    });
    expect(malformed!.isReliable(), isFalse);
    expect(
      const PoseLandmark(x: 0, y: 0, z: 0, presence: 1.5).isReliable(),
      isFalse,
    );
  });

  test('invalid native timestamp or landmark container fails safely', () {
    for (final timestamp in [null, -1, double.nan, '1']) {
      expect(() => PoseFrame.fromPlatform({'timestampMs': timestamp}),
          throwsFormatException);
    }
    expect(
      () => PoseFrame.fromPlatform({'timestampMs': 1, 'landmarks': 'bad'}),
      throwsFormatException,
    );
  });

  test('invalid geometry is omitted without losing world measurements', () {
    for (final entry in <String, Object?>{
      'previewWidth': 0,
      'rotationDegrees': 45,
      'matrix': [1, 0, double.nan, 0, 1, 0, 0, 0, 1],
      'revision': double.nan,
    }.entries) {
      expect(
        PoseGeometry.tryFromPlatform({...geometryMap(), entry.key: entry.value}),
        isNull,
      );
    }
  });
}

Map<String, Object> geometryMap() => {
      'imageWidth': 480,
      'imageHeight': 640,
      'rotationDegrees': 90,
      'mirrored': true,
      'previewWidth': 1080,
      'previewHeight': 1920,
      'matrix': [-1, 0, 1, 0, 1, 0, 0, 0, 1],
      'revision': 2,
    };
