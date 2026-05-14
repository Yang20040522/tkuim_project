// lib/actions/side_pinch_action.dart
//
// 側捏訓練 Flutter 端職責：
//   ✅ 視覺進度條（progress）計算 → 傳給 HandOverlayWidget
//   ✅ isReadyToReceiveUpdates = true，讓 trainingStream 直接放行
//   ❌ 次數、feedback、完成判斷 → 全部交給 Kotlin trainingStream
//      （Flutter 端不自己算，避免兩個來源打架造成數字亂跳）

import '../services/mediapipe_service.dart';
import 'base_rehab_action.dart';
import 'rehab_action_callback.dart';

class SidePinchAction extends BaseRehabAction {
  final int difficulty; // 1=初階 2=中階 3=進階

  // 只用來算視覺進度條，不影響計數
  static const double _smoothingFactor = 0.3;
  double _smoothedPinchDistance = 0.0;

  SidePinchAction({
    required RehabActionCallback callback,
    this.difficulty = 1,
  }) : super(callback);

  // ── BaseRehabAction ─────────────────────────────────────────────

  @override
  bool get isReadyToReceiveUpdates => true; // 不需倒數，直接放行 trainingStream

  @override
  String get initialFeedback => '請先將手指完全打開';

  @override
  String get initialInstruction => '準備開始側捏訓練';

  @override
  void processLandmarks(List<Landmark> landmarks) {
    if (landmarks.length < 18) return;

    final thumbTip  = landmarks[4];
    final indexPip  = landmarks[6];
    final wrist     = landmarks[0];
    final middleMcp = landmarks[9];

    // 掌長正規化捏合距離
    final palmLen  = _hypot(middleMcp.x - wrist.x, middleMcp.y - wrist.y);
    final pinchDist = _hypot(thumbTip.x - indexPip.x, thumbTip.y - indexPip.y);
    final ratio = (pinchDist / palmLen) * 100;

    _smoothedPinchDistance =
        (_smoothingFactor * ratio) + ((1 - _smoothingFactor) * _smoothedPinchDistance);

    // 視覺進度 0.0（完全張開）→ 1.0（完全捏緊）
    final pinchThreshold = difficulty == 1 ? 55.0 : difficulty == 2 ? 45.0 : 40.0;
    final openThreshold  = difficulty == 1 ? 58.0 : 65.0;
    final totalRange     = openThreshold - pinchThreshold;
    final rawProgress    = 1.0 - ((_smoothedPinchDistance - pinchThreshold) / totalRange);
    final progress       = rawProgress.clamp(0.0, 1.0).toDouble();

    // 只更新進度條，repCount 完全不動（交給 trainingStream）
    callback.onStatsChanged(
      progress: progress,
      speedState: 0,
    );
  }

  // ── 數學工具 ─────────────────────────────────────────────────────

  double _hypot(double dx, double dy) => _sqrt(dx * dx + dy * dy);

  double _sqrt(double n) {
    if (n <= 0) return 0;
    double x = n;
    for (int i = 0; i < 20; i++) {
      x = (x + n / x) / 2;
    }
    return x;
  }
}