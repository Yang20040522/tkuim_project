import 'package:flutter/material.dart';

import 'models/pose_frame.dart';
import 'pose_coordinate_transformer.dart';

class PoseConnection {
  const PoseConnection(this.start, this.end);

  final PoseLandmarkType start;
  final PoseLandmarkType end;
}

class PoseSkeletonPainter extends CustomPainter {
  const PoseSkeletonPainter({required this.frame, this.minConfidence = 0.5});

  final PoseFrame? frame;
  final double minConfidence;

  @override
  void paint(Canvas canvas, Size size) {
    final current = frame;
    if (current == null) return;
    final transformer = PoseCoordinateTransformer(current.geometry);
    if (!transformer.isCompatibleWith(size)) return;
    final points = <PoseLandmarkType, Offset>{};
    for (final entry in current.landmarks.entries) {
      if (!entry.value.isReliable(minConfidence)) continue;
      final point = transformer.transform(entry.value, size);
      if (point != null) points[entry.key] = point;
    }
    final linePaint = Paint()
      ..color = const Color(0xFF66E5CF)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final pointPaint = Paint()..color = const Color(0xFFFFD966);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final edge in connections) {
      final start = points[edge.start];
      final end = points[edge.end];
      if (start != null && end != null) {
        canvas.drawLine(start, end, linePaint);
      }
    }
    for (final point in points.values) {
      canvas.drawCircle(point, 3.5, pointPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PoseSkeletonPainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.minConfidence != minConfidence;

  /// Major anatomical connections, independent of preview mirror direction.
  static const connections = <PoseConnection>[
    PoseConnection(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
    PoseConnection(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow),
    PoseConnection(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist),
    PoseConnection(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
    PoseConnection(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist),
    PoseConnection(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip),
    PoseConnection(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
    PoseConnection(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),
    PoseConnection(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee),
    PoseConnection(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
    PoseConnection(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee),
    PoseConnection(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
    PoseConnection(PoseLandmarkType.leftWrist, PoseLandmarkType.leftPinky),
    PoseConnection(PoseLandmarkType.leftWrist, PoseLandmarkType.leftIndex),
    PoseConnection(PoseLandmarkType.leftWrist, PoseLandmarkType.leftThumb),
    PoseConnection(PoseLandmarkType.leftPinky, PoseLandmarkType.leftIndex),
    PoseConnection(PoseLandmarkType.rightWrist, PoseLandmarkType.rightPinky),
    PoseConnection(PoseLandmarkType.rightWrist, PoseLandmarkType.rightIndex),
    PoseConnection(PoseLandmarkType.rightWrist, PoseLandmarkType.rightThumb),
    PoseConnection(PoseLandmarkType.rightPinky, PoseLandmarkType.rightIndex),
    PoseConnection(PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel),
    PoseConnection(PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex),
    PoseConnection(PoseLandmarkType.leftAnkle, PoseLandmarkType.leftFootIndex),
    PoseConnection(PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel),
    PoseConnection(PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex),
    PoseConnection(PoseLandmarkType.rightAnkle, PoseLandmarkType.rightFootIndex),
  ];
}
