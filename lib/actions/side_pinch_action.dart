// lib/actions/side_pinch_action.dart
//
// 側捏訓練 — 完整判斷邏輯（從 Kotlin SidePinchAction.kt 搬移過來）
// 次數、feedback、完成判斷全部在 Dart 這裡處理，不再依賴 trainingStream
//
// 🩺 治療師回饋調整(2026-08-20):
//   1. 簡單難度門檻放寬(55→64)，稍微有點弧度就能觸發 PINCHED，讓初階病人容易拿到成就感
//   2. 高階門檻收緊(40→36)，要求更接近完美
//   3. 新增真正的平均分數累積(_scoreSum/_scoreCount)，_checkLevelUp 改用平均分數
//      判斷是否過關，取代原本寫死「完成 10 次就 80 分」的簡化邏輯
//   4. 過關門檻依難度分級：初階 40 分、中階 60 分、高階 80 分
//      → 對應「簡單 20~40 分達標，心態上不要強度太高；難的要盡量做到完美」
//
// 🆕 2026-08-22 治療師回饋:
//   支援「自動升級／手動升級」開關(autoLevelUp)。
//   達標時:
//     - autoLevelUp = true  → 維持原本行為,立刻自動進下一階
//     - autoLevelUp = false → 卡住不繼續判定,等外部呼叫
//       confirmLevelUp()/declineLevelUp()(例如跳出「要不要升級」對話框)
//   實作 HandLevelUpControllable,讓 RehabSessionController/UI 可以查詢與操作。
//   未達門檻(平均分數不夠)時維持原行為:不算升級決策,直接原地重來這個難度,
//   跟 autoLevelUp 開關無關。

import 'dart:async';
import '../services/mediapipe_service.dart';
import 'base_rehab_action.dart';
import 'rehab_action_callback.dart';
import '../services/hand_voice_service.dart';

class SidePinchAction extends BaseRehabAction implements HandLevelUpControllable {
  final int difficulty; // 1=初階 2=中階 3=進階(起始難度)
  int _targetReps;      // 🆕 改成可變,手動確認升級時可以自訂下一階次數
  final bool autoLevelUp; // 🆕

  final List<String> _mistakeLogs = [];
  DateTime _sessionStartTime = DateTime.now();

  double _smoothedPinchDistance = 0.0;
  final List<String> _pinchStateBuffer = [];
  String _lastConfirmedPinchState = '';

  int _currentLevel = 1;
  bool _isTransitioning = false;
  DateTime _transitionStartTime = DateTime.now();
  int _lastCountdownSec = -1;
  Timer? _transitionTimer;

  double _repStartWristX = 0.0;
  double _repStartWristY = 0.0;

  int _repCount = 0;
  DateTime _lastRepTime = DateTime.now();

  // 平均分數累積，用來決定是否真的達標升級
  int _scoreSum = 0;
  int _scoreCount = 0;
  int _lastAvgScore = 0; // 🆕 給手動「不升級,直接結束」時結算訊息用

  // 🆕 手動升級:是否正等待使用者確認
  bool _pendingLevelUp = false;
  bool _pendingHasNextLevel = false;
  String _pendingNextLevelLabel = '';

  static const double _smoothingFactor = 0.2;

  SidePinchAction({
    required RehabActionCallback callback,
    this.difficulty = 1,
    int targetReps = 10,
    this.autoLevelUp = true, // 🆕
  })  : _targetReps = targetReps,
        super(callback) {
    _startLevel(difficulty);
  }

  // ── BaseRehabAction ─────────────────────────────────────────────

  @override
  bool get isReadyToReceiveUpdates => true;

  @override
  String get initialFeedback => '請先將手指完全打開';

  @override
  String get initialInstruction => '準備開始側捏訓練';

  @override
  void dispose() {
    _transitionTimer?.cancel();
  }

  // 🆕 對外相容:保留 targetReps 讀取入口
  int get targetReps => _targetReps;

  // ── HandLevelUpControllable ─────────────────────────────────────

  @override
  bool get isPendingLevelUp => _pendingLevelUp;

  @override
  bool get hasNextLevel => _pendingHasNextLevel;

  @override
  String get nextLevelLabel => _pendingNextLevelLabel;

  @override
  void confirmLevelUp({int? customTargetReps}) {
    if (!_pendingLevelUp) return;
    _pendingLevelUp = false;
    if (customTargetReps != null && customTargetReps > 0) {
      _targetReps = customTargetReps;
    }
    _startLevel(_currentLevel + 1);
  }

  @override
  void declineLevelUp() {
    if (!_pendingLevelUp) return;
    _pendingLevelUp = false;
    _finishTraining(_lastAvgScore);
  }

  // ── 主要邏輯 ─────────────────────────────────────────────────────

  @override
  void processLandmarks(List<Landmark> landmarks) {
    if (_pendingLevelUp) return; // 🆕 等待使用者確認期間,暫停判定
    if (landmarks.length < 18) return;

    if (_isTransitioning) {
      _handleTransition();
      return;
    }

    final thumbTip  = landmarks[4];
    final indexPip  = landmarks[6];
    final wrist     = landmarks[0];
    final middleMcp = landmarks[9];

    final palmLen   = _hypot(middleMcp.x - wrist.x, middleMcp.y - wrist.y);
    final pinchDist = _hypot(thumbTip.x - indexPip.x, thumbTip.y - indexPip.y);
    final ratio = (pinchDist / palmLen) * 100;

    _smoothedPinchDistance =
        (_smoothingFactor * ratio) + ((1 - _smoothingFactor) * _smoothedPinchDistance);

    callback.onStatsChanged(accuracy: _smoothedPinchDistance);

    // 🩺 難度門檻：簡單放寬到 64（有點弧度就算捏緊），進階收緊到 36（要求更精準）
    final pinchThreshold = _currentLevel == 1 ? 64.0 : _currentLevel == 2 ? 45.0 : 36.0;
    final openThreshold  = _currentLevel == 1 ? 72.0 : _currentLevel == 2 ? 58.0 : 65.0;
    final totalRange     = openThreshold - pinchThreshold;
    final rawProgress    = 1.0 - ((_smoothedPinchDistance - pinchThreshold) / totalRange);
    final progress       = rawProgress.clamp(0.0, 1.0);

    callback.onStatsChanged(progress: progress, speedState: 0);

    final currentState = _smoothedPinchDistance < pinchThreshold
        ? 'PINCHED'
        : _smoothedPinchDistance > openThreshold
            ? 'OPENED'
            : 'MID';

    _pinchStateBuffer.add(currentState);
    if (_pinchStateBuffer.length > 8) _pinchStateBuffer.removeAt(0);

    final isStablePinch = _pinchStateBuffer.where((s) => s == 'PINCHED').length >= 5;
    final isStableOpen  = _pinchStateBuffer.where((s) => s == 'OPENED').length >= 5;

    if (isStablePinch && _lastConfirmedPinchState != 'PINCHED') {
      if (_lastConfirmedPinchState == 'OPENED') {
        final now = DateTime.now();
        final durationMs = now.difference(_lastRepTime).inMilliseconds;

        if (durationMs > 1200) {
          _repCount++;
          _lastRepTime = now;
          var score = 100;

          // 🩺 簡單模式不扣分，稍微有點弧度就給高分；進階模式才嚴格檢查
          if (_currentLevel == 3) {
            final wristMove = _hypot(wrist.x - _repStartWristX, wrist.y - _repStartWristY);
            if (wristMove > 0.05) {
              score -= 20;
              _mistakeLogs.add('第 $_repCount 次：手腕晃動過大');
            }
            if (durationMs > 2000) {
              score -= 15;
              _mistakeLogs.add('第 $_repCount 次：側捏動作不夠流暢');
            }
          }
          score = score < 60 ? 60 : score;

          // 累積分數，供 _checkLevelUp 判斷平均表現
          _scoreSum += score;
          _scoreCount++;

          callback.onFeedbackChanged('✅ 捏緊了！(本次: $score 分)', '請將手指完全打開');
          callback.onStatsChanged(repCount: _repCount);
          HandVoiceService.speak('捏緊了');

          if (_repCount >= _targetReps) _checkLevelUp();
        } else {
          _lastRepTime = DateTime.now();
          _mistakeLogs.add('未計入次數：開合動作過快');
          callback.onFeedbackChanged('⚠️ 動作太快', '請放慢速度，重新打開');
          HandVoiceService.speak('太快');
        }
      } else {
        callback.onFeedbackChanged('✅ 捏緊完成', '請將手指完全打開');
      }
      _lastConfirmedPinchState = 'PINCHED';

    } else if (isStableOpen && _lastConfirmedPinchState != 'OPENED') {
      callback.onFeedbackChanged('✅ 已張開', '請用力側捏');
      _repStartWristX = wrist.x;
      _repStartWristY = wrist.y;
      _lastConfirmedPinchState = 'OPENED';
    }
  }

  // ── 私有邏輯 ─────────────────────────────────────────────────────

  String _levelName(int level) => level == 1
      ? '初階 (微幅動作)'
      : level == 2
          ? '中階 (標準側捏)'
          : '進階 (懸空連擊)';

  void _startLevel(int level) {
    _currentLevel = level;
    _repCount = 0;
    _scoreSum = 0;
    _scoreCount = 0;
    _pinchStateBuffer.clear();
    _lastConfirmedPinchState = '';
    _isTransitioning = true;
    _transitionStartTime = DateTime.now();
    _lastCountdownSec = -1;
    _mistakeLogs.clear();
    _sessionStartTime = DateTime.now();

    final levelName = _levelName(level);

    callback.onLevelUp(newLevel: level, levelLabel: 'Lv.$level - $levelName', newTargetReps: _targetReps);

    callback.onFeedbackChanged('側捏訓練 Lv.$level - $levelName', '準備進入關卡...');
    callback.onStatsChanged(repCount: 0);

    // 倒數計時
    _transitionTimer?.cancel();
    _transitionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _handleTransition();
    });
  }

  void _handleTransition() {
    final elapsed = DateTime.now().difference(_transitionStartTime).inMilliseconds;

    if (elapsed < 3000) {
      final remain = 3 - (elapsed ~/ 1000);
      if (remain != _lastCountdownSec && remain > 0) {
        _lastCountdownSec = remain;
        callback.onCountdownChanged(
            isCountingDown: true, seconds: remain, isDone: false);
      }
    } else {
      _transitionTimer?.cancel();
      _isTransitioning = false;
      _lastRepTime = DateTime.now();
      _lastCountdownSec = -1;
      callback.onCountdownChanged(
          isCountingDown: false, seconds: 0, isDone: true);
      callback.onFeedbackChanged('開始！', '請先將手指完全打開');
      HandVoiceService.speak('開始');
    }
  }

  // 🩺 依難度給不同過關門檻：初階 40 分、中階 60 分、高階 80 分
  int get _passScoreThreshold => switch (_currentLevel) {
        1 => 40,
        2 => 60,
        _ => 80,
      };

  // 🆕 改造:達標時依 autoLevelUp 決定「直接升級」或「卡住等確認」
  void _checkLevelUp() {
    final avgScore = _scoreCount > 0 ? (_scoreSum / _scoreCount).round() : 0;
    _lastAvgScore = avgScore;

    final hasNext = _currentLevel < 3;
    final passed = avgScore >= _passScoreThreshold;

    if (hasNext && passed) {
      if (autoLevelUp) {
        _startLevel(_currentLevel + 1);
      } else {
        _pendingLevelUp = true;
        _pendingHasNextLevel = true;
        _pendingNextLevelLabel = _levelName(_currentLevel + 1);
        callback.onFeedbackChanged(
          '太棒了！平均 $avgScore 分',
          '要挑戰下一階「$_pendingNextLevelLabel」嗎？',
        );
        HandVoiceService.speak('過關了');
      }
    } else if (hasNext && !passed) {
      // 未達門檻：不升級，原地重新開始這個難度，讓病人再練習
      // (跟 autoLevelUp 開關無關,因為這不是「升級」決策)
      callback.onFeedbackChanged(
        '再加油一點！平均 $avgScore 分',
        '目前難度需要 $_passScoreThreshold 分才能升級，繼續練習',
      );
      _startLevel(_currentLevel);
    } else {
      // 已經是最高難度 → 結束整場訓練
      _finishTraining(avgScore);
    }
  }

  void _finishTraining(int avgScore) {
    final durationSeconds =
        DateTime.now().difference(_sessionStartTime).inSeconds;
    callback.onFeedbackChanged('🎉 訓練結束！平均 $avgScore 分', '辛苦了');
    HandVoiceService.speak('訓練結束');
    callback.onTrainingComplete(
      repCount: _repCount,
      durationSeconds: durationSeconds,
      mistakeLogs: List.from(_mistakeLogs),
    );
  }

  // ── 數學工具 ─────────────────────────────────────────────────────

  double _hypot(double dx, double dy) {
    final n = dx * dx + dy * dy;
    if (n <= 0) return 0;
    double x = n;
    for (int i = 0; i < 20; i++) {
      x = (x + n / x) / 2;
    }
    return x;
  }
}