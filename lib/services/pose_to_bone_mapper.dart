// lib/services/pose_to_bone_mapper.dart
//
// ══════════════════════════════════════════════════════════════════
//  RTMPose 2D 關節點 → 3D 模型骨頭旋轉角度
//
//  職責單一：只做「座標轉角度」這一件事，不碰相機、不碰 ONNX、
//  不碰 WebView。輸入是 BodyPoseEngine 輸出的 PoseData（133 點），
//  輸出是給 Three.js 用的骨頭旋轉角度（單位：度）。
//
//  座標系統限制（重要）：
//    RTMPose 給的是「純 2D 平面座標」(x, y)，沒有深度資訊 (z)。
//    這代表算出來的角度是「2D 投影角度」，不是真正精確的 3D
//    空間旋轉角度。對於復健動作這種「主要在畫面平面內活動」的
//    場景，這個近似已經足夠呈現「模型有跟著動」的效果，但無法
//    分辨「手往鏡頭前後伸」這種純深度方向的動作。
//
//  使用方式：
//    final mapper = PoseToBoneMapper();
//    final angles = mapper.computeAngles(poseData);
//    // angles 是 Map<String, double>，key 對應到測試頁面驗證過的
//    // 6 個滑桿 key：'shoulder-l', 'elbow-l', 'wrist-l',
//    //              'shoulder-r', 'elbow-r', 'wrist-r'
// ══════════════════════════════════════════════════════════════════
 
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
 
  /// 轉成 Map，方便直接餵給 JS bridge（key 對應測試頁面的滑桿 id）
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
  // 身體骨架點（COCO 17 點排列順序的前 17 個）
  static const int _leftShoulder = 5;
  static const int _rightShoulder = 6;
  static const int _leftElbow = 7;
  static const int _rightElbow = 8;
  static const int _leftHip = 11;
  static const int _rightHip = 12;
 
  // 手部精確點（wholebody 133 點才有，比 17 點版更準確）
  static const int _leftWristPrecise = 91;
  static const int _leftMiddleBase = 100; // 左手中指根部，代表手掌延伸方向
  static const int _rightWristPrecise = 112;
  static const int _rightMiddleBase = 121; // 右手中指根部
 
  static const double _scoreThreshold = 0.3;
 
  // ── EMA 平滑：避免角度抖動，讓模型動作看起來更穩定 ─────────────
  BoneAngles? _smoothed;
  static const double _smoothAlpha = 0.35; // 越小越平滑，但延遲越高
 
  /// 主入口：輸入一幀 PoseData，輸出平滑後的骨頭角度
  BoneAngles computeAngles(PoseData data) {
    if (data.keypoints.length < 133 || data.scores.length < 133) {
      return _smoothed ?? BoneAngles.zero;
    }
 
    final raw = _computeRawAngles(data);
    _smoothed = _applySmoothing(raw);
    return _smoothed!;
  }
 
  // ── 原始角度計算（未平滑）────────────────────────────────────
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
 
    // ── 右手（注意：右肩抬高軸向跟左邊相反，但這裡只算「角度大小」，
    //    正負號的鏡像處理交給 WebView 端的 AXIS_CONFIG 負責，
    //    跟測試頁面驗證時的職責切分一致）──
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
 
  // ── 手肘彎曲角度 ─────────────────────────────────────────────
  // 0° = 手臂打直, 150° = 完全彎曲（對齊測試頁面滑桿範圍 0~150）
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
 
  // ── 上臂抬高角度 ─────────────────────────────────────────────
  // 0° = 手臂自然垂下, 160° = 舉高過頭（對齊測試頁面滑桿範圍 0~160）
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
 
  // ── 手腕旋轉角度（近似）─────────────────────────────────────
  // 用「前臂方向」vs「手掌延伸方向（中指根部）」的夾角正負號，
  // 估計手腕的左右偏轉。-90°~90°，對齊測試頁面滑桿範圍。
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
 
  // ── 共用：兩向量夾角（0°~180°）─────────────────────────────
  double _vectorAngleDegrees(double v1x, double v1y, double v2x, double v2y) {
    final dot = v1x * v2x + v1y * v2y;
    final mag1 = math.sqrt(v1x * v1x + v1y * v1y);
    final mag2 = math.sqrt(v2x * v2x + v2y * v2y);
 
    if (mag1 == 0 || mag2 == 0) return 180.0;
 
    var cosAngle = dot / (mag1 * mag2);
    cosAngle = cosAngle.clamp(-1.0, 1.0);
    return math.acos(cosAngle) * 180.0 / math.pi;
  }
 
  // ── EMA 平滑：跟 BodyPoseEngine 裡骨架點平滑邏輯同一套思路，
  //    避免每幀角度跳動造成 3D 模型抖動 ──────────────────────
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
 
  /// 重置平滑狀態（例如使用者離開鏡頭範圍時呼叫，避免下次回來時
  /// 角度從舊值瞬間跳變）
  void reset() {
    _smoothed = null;
  }
}