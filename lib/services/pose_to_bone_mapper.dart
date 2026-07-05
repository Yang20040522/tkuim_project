// lib/services/pose_to_bone_mapper.dart

import 'dart:math' as math;
import 'dart:ui';
import '../models/pose_data.dart';

class BoneAngles {
  final double shoulderL;
  final double elbowL;
  final double wristL;
  final double shoulderR;
  final double elbowR;
  final double wristR;

  const BoneAngles({
    required this.shoulderL,
    required this.elbowL,
    required this.wristL,
    required this.shoulderR,
    required this.elbowR,
    required this.wristR,
  });

  static const zero = BoneAngles(
    shoulderL: 0,
    elbowL: 0,
    wristL: 0,
    shoulderR: 0,
    elbowR: 0,
    wristR: 0,
  );

  Map<String, double> toMap() => {
        'shoulder-l': shoulderL,
        'elbow-l': elbowL,
        'wrist-l': wristL,
        'shoulder-r': shoulderR,
        'elbow-r': elbowR,
        'wrist-r': wristR,
      };
}

class PoseToBoneMapper {
  // ── RTMPose Wholebody 133 點關鍵索引 ───────────────────────────
  static const int _leftShoulder = 5;
  static const int _rightShoulder = 6;
  static const int _leftElbow = 7;
  static const int _rightElbow = 8;
  static const int _leftHip = 11;
  static const int _rightHip = 12;

  static const int _leftWristPrecise = 91;
  static const int _leftMiddleBase = 100;
  static const int _rightWristPrecise = 112;
  static const int _rightMiddleBase = 121;

  static const double _scoreThreshold = 0.3;

  // ── 平滑係數(越大越靈敏,越小越平滑)─────────────────────────
  // 舊值:0.35(過度平滑,拖延感明顯)
  // 新值:0.7(靈敏,幾乎無延遲)
  static const double _smoothAlpha = 0.7;

  // ── 回 rest 的平滑係數(小,才會「慢慢回」不突然)─────────────
  // 0.15 大概在 0.3 秒內收回 rest 姿勢
  static const double _restReturnAlpha = 0.15;

  BoneAngles? _smoothed;

  /// 主入口:輸入一幀 PoseData,輸出平滑後的骨頭角度
  BoneAngles computeAngles(PoseData data) {
    // ── 沒偵測到:平滑回 rest(不是瞬間歸零)─────────────────
    if (data.keypoints.length < 133 || data.scores.length < 133) {
      return _returnToRest();
    }

    final raw = _computeRawAngles(data);
    _smoothed = _applySmoothing(raw);
    return _smoothed!;
  }

  // ── 沒偵測到 → 慢慢收回 rest ────────────────────────────────
  BoneAngles _returnToRest() {
    if (_smoothed == null) return BoneAngles.zero;
    final prev = _smoothed!;
    double lerp(double v) => v + (0 - v) * _restReturnAlpha;

    _smoothed = BoneAngles(
      shoulderL: lerp(prev.shoulderL),
      elbowL: lerp(prev.elbowL),
      wristL: lerp(prev.wristL),
      shoulderR: lerp(prev.shoulderR),
      elbowR: lerp(prev.elbowR),
      wristR: lerp(prev.wristR),
    );
    return _smoothed!;
  }

  BoneAngles _computeRawAngles(PoseData data) {
    final kp = data.keypoints;
    final sc = data.scores;

    double shoulderL = _smoothed?.shoulderL ?? 0;
    double elbowL = _smoothed?.elbowL ?? 0;
    double wristL = _smoothed?.wristL ?? 0;
    double shoulderR = _smoothed?.shoulderR ?? 0;
    double elbowR = _smoothed?.elbowR ?? 0;
    double wristR = _smoothed?.wristR ?? 0;

    // ── 左手 ──
    if (_visible(sc, _leftHip) &&
        _visible(sc, _leftShoulder) &&
        _visible(sc, _leftElbow)) {
      shoulderL = _shoulderRaiseDegrees(
        kp[_leftShoulder],
        kp[_leftElbow],
        kp[_leftHip],
      );
    }
    if (_visible(sc, _leftShoulder) &&
        _visible(sc, _leftElbow) &&
        _visible(sc, _leftWristPrecise)) {
      elbowL = _elbowFlexDegrees(
        kp[_leftShoulder],
        kp[_leftElbow],
        kp[_leftWristPrecise],
      );
    }
    if (_visible(sc, _leftElbow) &&
        _visible(sc, _leftWristPrecise) &&
        _visible(sc, _leftMiddleBase)) {
      wristL = _wristTwistDegrees(
        kp[_leftElbow],
        kp[_leftWristPrecise],
        kp[_leftMiddleBase],
      );
    }

    // ── 右手 ──
    if (_visible(sc, _rightHip) &&
        _visible(sc, _rightShoulder) &&
        _visible(sc, _rightElbow)) {
      shoulderR = _shoulderRaiseDegrees(
        kp[_rightShoulder],
        kp[_rightElbow],
        kp[_rightHip],
      );
    }
    if (_visible(sc, _rightShoulder) &&
        _visible(sc, _rightElbow) &&
        _visible(sc, _rightWristPrecise)) {
      elbowR = _elbowFlexDegrees(
        kp[_rightShoulder],
        kp[_rightElbow],
        kp[_rightWristPrecise],
      );
    }
    if (_visible(sc, _rightElbow) &&
        _visible(sc, _rightWristPrecise) &&
        _visible(sc, _rightMiddleBase)) {
      wristR = _wristTwistDegrees(
        kp[_rightElbow],
        kp[_rightWristPrecise],
        kp[_rightMiddleBase],
      );
    }

    return BoneAngles(
      shoulderL: shoulderL,
      elbowL: elbowL,
      wristL: wristL,
      shoulderR: shoulderR,
      elbowR: elbowR,
      wristR: wristR,
    );
  }

  bool _visible(List<double> scores, int idx) =>
      idx < scores.length && scores[idx] > _scoreThreshold;

  double _elbowFlexDegrees(Offset shoulder, Offset elbow, Offset wrist) {
    final raw = _vectorAngleDegrees(
      shoulder.dx - elbow.dx,
      shoulder.dy - elbow.dy,
      wrist.dx - elbow.dx,
      wrist.dy - elbow.dy,
    );
    final flex = 180.0 - raw;
    return flex.clamp(0.0, 150.0);
  }

  double _shoulderRaiseDegrees(Offset shoulder, Offset elbow, Offset hip) {
    final raw = _vectorAngleDegrees(
      shoulder.dx - hip.dx,
      shoulder.dy - hip.dy,
      elbow.dx - shoulder.dx,
      elbow.dy - shoulder.dy,
    );
    final raise = 180.0 - raw;
    return raise.clamp(0.0, 160.0);
  }

  double _wristTwistDegrees(Offset elbow, Offset wrist, Offset middleBase) {
    final forearmX = wrist.dx - elbow.dx;
    final forearmY = wrist.dy - elbow.dy;
    final palmX = middleBase.dx - wrist.dx;
    final palmY = middleBase.dy - wrist.dy;

    final cross = forearmX * palmY - forearmY * palmX;
    final dot = forearmX * palmX + forearmY * palmY;

    final angle = math.atan2(cross, dot) * 180.0 / math.pi;
    return angle.clamp(-90.0, 90.0);
  }

  double _vectorAngleDegrees(double v1x, double v1y, double v2x, double v2y) {
    final dot = v1x * v2x + v1y * v2y;
    final mag1 = math.sqrt(v1x * v1x + v1y * v1y);
    final mag2 = math.sqrt(v2x * v2x + v2y * v2y);

    if (mag1 == 0 || mag2 == 0) return 180.0;

    var cosAngle = dot / (mag1 * mag2);
    cosAngle = cosAngle.clamp(-1.0, 1.0);
    return math.acos(cosAngle) * 180.0 / math.pi;
  }

  BoneAngles _applySmoothing(BoneAngles raw) {
    if (_smoothed == null) return raw;
    final prev = _smoothed!;
    double lerp(double a, double b) => a + (b - a) * _smoothAlpha;

    return BoneAngles(
      shoulderL: lerp(prev.shoulderL, raw.shoulderL),
      elbowL: lerp(prev.elbowL, raw.elbowL),
      wristL: lerp(prev.wristL, raw.wristL),
      shoulderR: lerp(prev.shoulderR, raw.shoulderR),
      elbowR: lerp(prev.elbowR, raw.elbowR),
      wristR: lerp(prev.wristR, raw.wristR),
    );
  }

  /// 重置平滑狀態
  void reset() {
    _smoothed = null;
  }
}