// lib/widgets/body_skeleton_widget.dart
import 'package:flutter/material.dart';
import '../models/pose_data.dart';
import '../services/body_pose_service.dart';

// 骨骼連線（從你的 main.dart 搬來）
const _skeletonConnections = [
  [0,1],[0,2],[1,3],[2,4],
  [5,6],[5,7],[7,9],[6,8],[8,10],
  [5,11],[6,12],[11,12],
  [11,13],[13,15],[12,14],[14,16],
  // 手指骨架...（省略，完整版和 main.dart 相同）
];

class BodySkeletonWidget extends StatelessWidget {
  final BodyPoseService service;
  const BodySkeletonWidget({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PoseData>(
      valueListenable: service.poseNotifier,
      builder: (_, data, __) => CustomPaint(
        painter: _SkeletonPainter(data),
      ),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  final PoseData data;
  static const threshold = 0.3;
  _SkeletonPainter(this.data);

  bool _valid(Offset p) =>
      p.dx > 0.02 && p.dx < 0.98 && p.dy > 0.02 && p.dy < 0.98;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.keypoints.isEmpty) return;
    final bone = Paint()
      ..color = Colors.greenAccent.withOpacity(0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final joint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 6;

    for (final c in _skeletonConnections) {
      final a = c[0], b = c[1];
      if (a >= data.keypoints.length || b >= data.keypoints.length) continue;
      if (data.scores[a] < threshold || data.scores[b] < threshold) continue;
      final pa = data.keypoints[a], pb = data.keypoints[b];
      if (!_valid(pa) || !_valid(pb)) continue;
      canvas.drawLine(
        Offset(pa.dx * size.width, pa.dy * size.height),
        Offset(pb.dx * size.width, pb.dy * size.height),
        bone,
      );
    }
    for (int i = 0; i < data.keypoints.length; i++) {
      if (data.scores[i] < threshold) continue;
      final p = data.keypoints[i];
      if (!_valid(p)) continue;
      canvas.drawCircle(
          Offset(p.dx * size.width, p.dy * size.height), 4, joint);
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) => true;
}