import 'dart:ui';

import 'package:flutter_body/features/pose_measurement/models/pose_frame.dart';
import 'package:flutter_body/features/pose_measurement/pose_coordinate_transformer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const size = Size(360, 640);

  test('native normalized preview matrix controls crop, not inferred aspect',
      () {
    final transform = PoseCoordinateTransformer(geometry(
      matrix: [2, 0, -0.5, 0, 1, 0, 0, 0, 1],
    ));
    expect(transform.transform(point(0.6, 0.25), size),
        offsetCloseTo(const Offset(252, 160)));
    // Cropped-out points stay outside the viewport; the painter clips them.
    expect(transform.transform(point(0, 0.5), size)!.dx, -180);
  });

  test('native rotation matrix is applied exactly once', () {
    final transform = PoseCoordinateTransformer(geometry(
      rotation: 90,
      matrix: [0, -1, 1, 1, 0, 0, 0, 0, 1],
    ));
    expect(transform.transform(point(0.2, 0.3), size),
        offsetCloseTo(const Offset(252, 128)));
  });

  test('rotation diagnostic does not rotate an already upright inference twice',
      () {
    final transform = PoseCoordinateTransformer(geometry(rotation: 270));
    expect(transform.transform(point(0.2, 0.3), size),
        offsetCloseTo(const Offset(72, 192)));
  });

  test('front mirror transforms display only, never swaps anatomical identities',
      () {
    final frame = PoseFrame(
      timestampMs: 1,
      geometry: geometry(
        mirrored: true,
        matrix: [-1, 0, 1, 0, 1, 0, 0, 0, 1],
      ),
      landmarks: {
        PoseLandmarkType.leftElbow: point(0.2, 0.3),
        PoseLandmarkType.rightElbow: point(0.8, 0.4),
      },
    );
    final transform = PoseCoordinateTransformer(frame.geometry);
    expect(
      transform.transform(frame.landmarks[PoseLandmarkType.leftElbow]!, size),
      offsetCloseTo(const Offset(288, 192)),
    );
    expect(
      transform.transform(frame.landmarks[PoseLandmarkType.rightElbow]!, size),
      offsetCloseTo(const Offset(72, 256)),
    );
    expect(frame.landmarks[PoseLandmarkType.leftElbow]!.x, 0.2);
    expect(frame.landmarks[PoseLandmarkType.rightElbow]!.x, 0.8);
  });

  test('different preview aspects work only with matching authoritative matrix',
      () {
    final landscape = PoseCoordinateTransformer(geometry(
      previewWidth: 1920,
      previewHeight: 1080,
      matrix: [1, 0, 0, 0, 2, -0.5, 0, 0, 1],
    ));
    expect(landscape.transform(point(0.25, 0.6), const Size(640, 360)),
        offsetCloseTo(const Offset(160, 252)));
    final square = PoseCoordinateTransformer(geometry(
      previewWidth: 1000,
      previewHeight: 1000,
      matrix: [1.5, 0, -0.25, 0, 1, 0, 0, 0, 1],
    ));
    expect(square.transform(point(0.5, 0.25), const Size(300, 300)),
        offsetCloseTo(const Offset(150, 75)));
  });

  test('stale layout geometry suppresses overlay instead of guessing new crop',
      () {
    final transform = PoseCoordinateTransformer(geometry());
    expect(transform.isCompatibleWith(size), isTrue);
    expect(transform.isCompatibleWith(const Size(640, 360)), isFalse);
    expect(transform.transform(point(0.5, 0.5), const Size(640, 360)), isNull);
    expect(transform.isCompatibleWith(const Size(360, 600)), isFalse);
    expect(transform.isCompatibleWith(const Size(360, 640.1)), isTrue);
  });

  test('homogeneous divisor is respected', () {
    final transform = PoseCoordinateTransformer(geometry(
      matrix: [1, 0, 0, 0, 1, 0, 0.5, 0, 1],
    ));
    expect(transform.transform(point(0.5, 0.25), size),
        offsetCloseTo(const Offset(144, 128)));
    expect(transform.transform(point(-2, 0.25), size), isNull);
  });

  test('missing, singular, nonfinite matrices and invalid sizes are rejected',
      () {
    final invalidGeometry = <PoseGeometry?>[
      null,
      geometry(matrix: []),
      geometry(matrix: List.filled(9, 0)),
      geometry(matrix: [1, 0, double.nan, 0, 1, 0, 0, 0, 1]),
      geometry(previewHeight: 0),
    ];
    for (final invalid in invalidGeometry) {
      expect(PoseCoordinateTransformer(invalid).transform(point(0, 0), size),
          isNull);
    }
    final transform = PoseCoordinateTransformer(geometry());
    expect(transform.transform(point(double.nan, 0), size), isNull);
    expect(transform.transform(point(0, 0), Size.zero), isNull);
    expect(transform.transform(point(0, 0), const Size(double.infinity, 640)),
        isNull);
  });
}

PoseGeometry geometry({
  List<double> matrix = const [1, 0, 0, 0, 1, 0, 0, 0, 1],
  int rotation = 0,
  bool mirrored = false,
  int previewWidth = 1080,
  int previewHeight = 1920,
}) =>
    PoseGeometry(
      imageWidth: 480,
      imageHeight: 640,
      rotationDegrees: rotation,
      mirrored: mirrored,
      previewWidth: previewWidth,
      previewHeight: previewHeight,
      matrix: matrix,
      revision: 1,
    );

PoseLandmark point(double x, double y) => PoseLandmark(x: x, y: y, z: 0);

Matcher offsetCloseTo(Offset expected) => predicate<Offset>(
      (actual) => (actual - expected).distance < 1e-8,
      'offset close to $expected',
    );
