import 'package:flutter/material.dart';
import 'package:flutter_body/features/pose_measurement/models/pose_frame.dart';
import 'package:flutter_body/features/pose_measurement/pose_skeleton_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('major torso and limb connections preserve anatomical side', () {
    final connections = PoseSkeletonPainter.connections;
    bool connected(PoseLandmarkType a, PoseLandmarkType b) => connections.any(
          (edge) => (edge.start == a && edge.end == b) ||
              (edge.start == b && edge.end == a),
        );
    expect(connected(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow),
        isTrue);
    expect(connected(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist),
        isTrue);
    expect(connected(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
        isTrue);
    expect(connected(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist),
        isTrue);
    expect(connected(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee), isTrue);
    expect(connected(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
        isTrue);
    expect(connected(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee),
        isTrue);
    expect(connected(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
        isTrue);
    expect(connected(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightElbow),
        isFalse);
    expect(connected(PoseLandmarkType.leftHip, PoseLandmarkType.rightKnee),
        isFalse);
    expect(connected(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip),
        isTrue);
    expect(connected(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
        isTrue);
    expect(connected(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip), isTrue);
    expect(connections.map((edge) => '${edge.start}:${edge.end}').toSet().length,
        connections.length);
  });

  testWidgets('empty, partial and invalid geometry painters are safe',
      (tester) async {
    final frames = <PoseFrame?>[
      null,
      PoseFrame(timestampMs: 1),
      PoseFrame(
        timestampMs: 2,
        landmarks: const {
          PoseLandmarkType.leftShoulder:
              PoseLandmark(x: 0.2, y: 0.3, z: 0, visibility: 0.9),
          PoseLandmarkType.leftElbow:
              PoseLandmark(x: 0.4, y: 0.3, z: 0, visibility: 0.1),
          PoseLandmarkType.rightElbow:
              PoseLandmark(x: double.nan, y: 0.3, z: 0, visibility: 0.9),
        },
        geometry: PoseGeometry(
          imageWidth: 480,
          imageHeight: 640,
          rotationDegrees: 90,
          mirrored: true,
          previewWidth: 300,
          previewHeight: 400,
          matrix: [-1, 0, 1, 0, 1, 0, 0, 0, 1],
          revision: 1,
        ),
      ),
    ];
    for (final frame in frames) {
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 400,
            child: CustomPaint(painter: PoseSkeletonPainter(frame: frame)),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    }
  });

  test('painter repaints only on new frame or confidence threshold', () {
    final frame = PoseFrame(timestampMs: 1);
    final original = PoseSkeletonPainter(frame: frame);
    expect(PoseSkeletonPainter(frame: frame).shouldRepaint(original), isFalse);
    expect(
        PoseSkeletonPainter(frame: PoseFrame(timestampMs: 2))
            .shouldRepaint(original),
        isTrue);
    expect(
      PoseSkeletonPainter(frame: frame, minConfidence: 0.7)
          .shouldRepaint(original),
      isTrue,
    );
  });
}
