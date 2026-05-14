// lib/actions/turn_palm_action.dart
//
// 翻掌訓練邏輯：
//   1. 偵測棍子是否垂直（index MCP 與 pinky MCP 角度差 ≤ 25°）
//   2. 穩定對齊後倒數 5 秒
//   3. 倒數完成才開放 trainingStream 更新（isReadyToReceiveUpdates = true）
//   4. 切換鏡頭時外部呼叫 resetForCameraFlip() 重置

import 'dart:async';
import '../services/mediapipe_service.dart';
import 'base_rehab_action.dart';
import 'rehab_action_callback.dart';

class TurnPalmAction extends BaseRehabAction {
  // 鏡像策略：與 TrainingScreen._overlayMirrored 保持一致
  // Kotlin 端已翻轉，Flutter 這裡預設不再翻
  final bool overlayMirrored;

  int _countdownSeconds = 5;
  bool _isCountingDown = false;
  bool _countdownDone = false;
  Timer? _countdownTimer;

  TurnPalmAction({
    required RehabActionCallback callback,
    this.overlayMirrored = false,
  }) : super(callback);

  // ── BaseRehabAction ─────────────────────────────────────────────

  @override
  bool get isReadyToReceiveUpdates => _countdownDone;

  @override
  String get initialFeedback => '將棍子保持垂直，開始倒數';

  @override
  String get initialInstruction => '對齊後保持5秒，才開始計算次數';

  @override
  void processLandmarks(List<Landmark> landmarks) {
    if (_countdownDone) return;
    if (landmarks.length < 18) return;

    final isStable = _computeIsStable(landmarks);

    if (isStable && !_isCountingDown) {
      _startCountdown();
    } else if (!isStable && _isCountingDown) {
      _resetCountdown();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
  }

  // ── 公開方法 ─────────────────────────────────────────────────────

  /// 切換鏡頭時由 TrainingScreen 呼叫
  void resetForCameraFlip() {
    if (_countdownDone) return; // 已完成就不重置
    _resetCountdown();
  }

  // ── 私有邏輯 ─────────────────────────────────────────────────────

  bool _computeIsStable(List<Landmark> landmarks) {
    final indexMcp = landmarks[5];
    final pinkyMcp = landmarks[17];

    final indexX = overlayMirrored ? (1.0 - indexMcp.x) : indexMcp.x;
    final pinkyX = overlayMirrored ? (1.0 - pinkyMcp.x) : pinkyMcp.x;

    final dx = indexX - pinkyX;
    final dy = indexMcp.y - pinkyMcp.y;

    final angle = _atan2(dy, dx) * (180 / 3.14159265);
    final deviation = (angle - (-90)).abs();
    final displayAngle = deviation > 180 ? 360 - deviation : deviation;

    return displayAngle <= 25;
  }

  void _startCountdown() {
    _isCountingDown = true;
    _countdownSeconds = 5;

    callback.onFeedbackChanged('很好！保持這個姿勢', '保持對齊，倒數結束後開始計算次數');
    callback.onCountdownChanged(
        isCountingDown: true, seconds: _countdownSeconds, isDone: false);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _countdownSeconds--;

      if (_countdownSeconds <= 0) {
        timer.cancel();
        _isCountingDown = false;
        _countdownDone = true;
        callback.onCountdownChanged(
            isCountingDown: false, seconds: 0, isDone: true);
        callback.onFeedbackChanged('開始翻掌！', '慢慢翻轉手腕');
      } else {
        callback.onCountdownChanged(
            isCountingDown: true,
            seconds: _countdownSeconds,
            isDone: false);
      }
    });
  }

  void _resetCountdown() {
    _countdownTimer?.cancel();
    _isCountingDown = false;
    _countdownSeconds = 5;

    callback.onCountdownChanged(
        isCountingDown: false, seconds: 5, isDone: false);
    callback.onFeedbackChanged('棍子歪掉了，重新對齊', '將棍子保持垂直，再次倒數5秒');
  }

  // ── 數學工具（dart:math 不用 import）─────────────────────────────

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
}