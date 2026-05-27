// lib/widgets/hand_overlay_widget.dart

import 'package:flutter/material.dart';
import '../services/mediapipe_service.dart';

class HandOverlayPainter extends CustomPainter {
  final List<Landmark> landmarks;
  final bool isMirrored;
  final bool showStickGuide;
  final bool showPinchGuide;
  final double progress;
  final int speedState;

  static const _connections = [
    [0, 1], [1, 2], [2, 3], [3, 4],
    [0, 5], [5, 6], [6, 7], [7, 8],
    [0, 9], [9, 10], [10, 11], [11, 12],
    [0, 13], [13, 14], [14, 15], [15, 16],
    [0, 17], [17, 18], [18, 19], [19, 20],
  ];

  const HandOverlayPainter({
    required this.landmarks,
    this.isMirrored = false,
    this.showStickGuide = false,
    this.showPinchGuide = false,
    this.progress = 0,
    this.speedState = 0,
  });

  double _x(Landmark lm, double width) {
    final raw = lm.x * width;
    return isMirrored ? width - raw : raw;
  }

  double _y(Landmark lm, double height) => lm.y * height;

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pointPaint = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    for (final conn in _connections) {
      if (conn[0] >= landmarks.length || conn[1] >= landmarks.length) continue;
      final s = landmarks[conn[0]];
      final e = landmarks[conn[1]];
      canvas.drawLine(
        Offset(_x(s, size.width), _y(s, size.height)),
        Offset(_x(e, size.width), _y(e, size.height)),
        linePaint,
      );
    }

    for (final lm in landmarks) {
      canvas.drawCircle(
        Offset(_x(lm, size.width), _y(lm, size.height)),
        6,
        pointPaint,
      );
    }

    if (showStickGuide && landmarks.length >= 18) {
      _drawStickGuide(canvas, size);
    }

    if (showPinchGuide && landmarks.length >= 9) {
      _drawPinchGuide(canvas, size);
    }

    if (!showStickGuide && !showPinchGuide && progress > 0) {
      _drawProgressArc(canvas, size);
    }
  }

  void _drawStickGuide(Canvas canvas, Size size) {
    final indexMcp = landmarks[5];
    final pinkyMcp = landmarks[17];

    final ix = _x(indexMcp, size.width);
    final iy = _y(indexMcp, size.height);
    final px = _x(pinkyMcp, size.width);
    final py = _y(pinkyMcp, size.height);

    final dx = ix - px;
    final dy = iy - py;
    final cx = (ix + px) / 2;
    final cy = (iy + py) / 2;

    final angle = _atan2(dy, dx) * (180 / 3.14159265);
    final deviation = (angle - (-90)).abs();
    final displayAngle = deviation > 180 ? 360 - deviation : deviation;
    final isStable = displayAngle <= 25;

    final stickPaint = Paint()
      ..color = isStable ? const Color(0xCC4CAF50) : const Color(0xCCFF4B4B)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const factor = 4.0;
    canvas.drawLine(
      Offset(cx - dx * factor, cy - dy * factor),
      Offset(cx + dx * factor, cy + dy * factor),
      stickPaint,
    );

    _drawText(
      canvas,
      isStable ? '完美對齊' : '偏差: ${displayAngle.toInt()}°',
      Offset(cx, cy - 60),
      isStable ? Colors.green : Colors.red,
    );
  }

  void _drawPinchGuide(Canvas canvas, Size size) {
    final thumbTip = landmarks[4];
    final indexPip = landmarks[6];

    final tx = _x(thumbTip, size.width);
    final ty = _y(thumbTip, size.height);
    final idx = _x(indexPip, size.width);
    final idy = _y(indexPip, size.height);

    final r = (255 * (1 - progress)).toInt().clamp(0, 255);
    final g = (215 + (40 * progress)).toInt().clamp(0, 255);

    final pinchPaint = Paint()
      ..color = Color.fromARGB(255, r, g, 0)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(tx, ty), Offset(idx, idy), pinchPaint);

    final centerX = (tx + idx) / 2;
    final centerY = (ty + idy) / 2;

    if (progress > 0.9) {
      const radius = 55.0;
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.greenAccent.withValues(alpha: 0.8),
            Colors.green.withValues(alpha: 0.3),
            Colors.transparent,
          ],
          stops: const [0, 0.5, 1],
        ).createShader(
            Rect.fromCircle(center: Offset(centerX, centerY), radius: radius))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(centerX, centerY), radius, glowPaint);
      _drawText(canvas, '✨ 捏緊了！',
          Offset(centerX, centerY - radius - 30), Colors.greenAccent);
    } else if (progress < 0.1) {
      _drawText(canvas, '👐 請張開',
          Offset(centerX, centerY - 50), const Color(0xFFFFD700));
    }
  }

  void _drawProgressArc(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;
    final wrist = landmarks[0];
    final wx = _x(wrist, size.width);
    final wy = _y(wrist, size.height);

    const radius = 120.0;
    final rect = Rect.fromCircle(center: Offset(wx, wy - 100), radius: radius);

    canvas.drawArc(rect, 3.14159, 3.14159, false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.2)
          ..strokeWidth = 18
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);

    canvas.drawArc(rect, 3.14159, 3.14159 * progress, false,
        Paint()
          ..color = speedState == 1
              ? const Color(0xFFFF9800)
              : Colors.greenAccent
          ..strokeWidth = 20
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);

    if (speedState == 1) {
      _drawText(canvas, '⚠️ 慢一點！',
          Offset(wx, wy - radius - 110), const Color(0xFFFF9800));
    }
  }

  void _drawText(Canvas canvas, String text, Offset position, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(position.dx - tp.width / 2, position.dy));
  }

  double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.14159265;
    if (x < 0 && y < 0) return _atan(y / x) - 3.14159265;
    if (x == 0 && y > 0) return 3.14159265 / 2;
    if (x == 0 && y < 0) return -3.14159265 / 2;
    return 0;
  }

  double _atan(double x) {
    const pi4 = 3.14159265 / 4;
    const pi2 = 3.14159265 / 2;
    if (x.abs() <= 1) {
      return pi4 * x - x * (x.abs() - 1) * (0.2447 + 0.0663 * x.abs());
    }
    return pi2 -
        (pi4 / x) +
        (1 / x) * ((1 / x).abs() - 1) * (0.2447 + 0.0663 * (1 / x).abs());
  }

  @override
  bool shouldRepaint(HandOverlayPainter old) {
    // ✅ 修正：比較內容而非 List 參考，避免每幀都重繪
    if (old.landmarks.length != landmarks.length) return true;
    if (old.progress != progress) return true;
    if (old.speedState != speedState) return true;
    if (old.showStickGuide != showStickGuide) return true;
    if (old.showPinchGuide != showPinchGuide) return true;
    if (old.isMirrored != isMirrored) return true;
    for (int i = 0; i < landmarks.length; i++) {
      if (old.landmarks[i].x != landmarks[i].x ||
          old.landmarks[i].y != landmarks[i].y) {
        return true;
      }
    }
    return false;
  }
}

class HandOverlayWidget extends StatelessWidget {
  final List<Landmark> landmarks;
  final bool isMirrored;
  final bool showStickGuide;
  final bool showPinchGuide;
  final double progress;
  final int speedState;

  const HandOverlayWidget({
    super.key,
    required this.landmarks,
    this.isMirrored = false,
    this.showStickGuide = false,
    this.showPinchGuide = false,
    this.progress = 0,
    this.speedState = 0,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(                // ✅ 新增：隔離重繪，不影響父層
      child: CustomPaint(
        painter: HandOverlayPainter(
          landmarks: landmarks,
          isMirrored: isMirrored,
          showStickGuide: showStickGuide,
          showPinchGuide: showPinchGuide,
          progress: progress,
          speedState: speedState,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}