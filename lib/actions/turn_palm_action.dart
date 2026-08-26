// lib/actions/turn_palm_action.dart
//
// 翻掌訓練 — 完整判斷邏輯（從 Kotlin TurnPalmAction.kt 搬移過來）
// 階段一：偵測棍子垂直並穩定 5 秒
// 階段二：偵測內外翻轉次數
// 全部在 Dart 這裡處理，不再依賴 trainingStream
//
// ── 本版改動重點（修正「卡住」問題）─────────────────────────────
// 1. 階段一：單幀抖動超標不再立刻重置倒數，改為「容錯緩衝」
//    （連續超標超過 _stage1GraceMs 才真正判定失敗重來）
// 2. 階段一：倒數「顯示」與「實際完成判定」原本是兩套獨立邏輯，
//    容易因幀率不穩對不上（畫面顯示倒數完成但卡在階段一）。
//    現在統一由同一個 Timer 直接計算真實經過時間來判斷，
//    不再依賴 processLandmarks 的呼叫頻率。
// 3. 階段二：原本用「最近 8 幀中要有 5 幀同狀態」的多數決，
//    在幀率不穩或翻轉速度快時容易一直湊不滿，導致次數卡住不加。
//    改為「連續 N 幀同狀態」判定，反應更快、更不容易卡住。
// 4. 階段二：targetDx 改用手掌尺寸正規化，避免使用者距離鏡頭
//    遠近不同時，翻轉判定忽鬆忽緊。⚠️ _targetRatioLevel1/2
//    這兩個常數需要你實測調整，目前只是估計值。
// 5. 🆕【修卡頓】階段一「棍子歪了」原本只要角度不合格就「每一幀」
//    呼叫一次 HandVoiceService.speak('歪了')。MediaPipe 通常
//    15~30fps 進 processLandmarks，等於每秒狂呼叫 TTS 15~30 次，
//    塞爆 platform channel，拖累畫面渲染造成明顯卡頓。
//    現在改成「只在剛進入歪斜狀態的那一刻播一次」，角度重新合格後
//    才會重置旗標、允許下次再播放。onFeedbackChanged 這種純文字
//    更新维持不變（不呼叫原生 API，成本低很多）。

import 'dart:async';
import '../services/mediapipe_service.dart';
import 'base_rehab_action.dart';
import 'rehab_action_callback.dart';
import '../services/hand_voice_service.dart';

enum _Stage { stage1, transitioning, stage2 }

class TurnPalmAction extends BaseRehabAction implements LevelUpControllable {
  final bool overlayMirrored;
  final int startingLevel;
  int targetReps; // 拿掉 final,支援自訂次數覆蓋

  int _currentLevel = 1;
  bool _pendingLevelUp = false;
  _Stage _currentStage = _Stage.stage1;

  // 階段一
  double _smoothedAngleStage1 = 0.0;
  bool _isCurrentlyStable = false;
  DateTime _holdStartTime = DateTime.now();

  // 🆕 階段一容錯緩衝：短暫超標不立刻重置
  DateTime? _badStartTime;
  static const int _stage1GraceMs = 400; // 容許連續超標 400ms 內都算「還在穩定」

  // 🆕 階段一「歪了」語音節流旗標：同一次歪斜期間只播一次
  bool _hasSpokenTilted = false;

  // 倒數
  bool _isCountingDown = false;
  bool _countdownDone = false;
  int _countdownSeconds = 5;
  Timer? _countdownTimer;

  // 階段二
  String _pendingState = '';
  int _pendingStateCount = 0;
  static const int _requiredConsecutiveFrames = 4; // 🆕 取代原本的 8 幀取 5 多數決
  String _lastConfirmedState = '';
  int _repCount = 0;
  DateTime _lastRepTime = DateTime.now();
  double _currentRepMaxWobble = 0.0;

  // 🆕 階段二翻轉幅度正規化用的比例（以手掌寬度為基準）
  // ⚠️ 這兩個值是估計值，請依實際測試結果調整
  static const double _targetRatioLevel1 = 0.30;
  static const double _targetRatioLevel2 = 0.55;

  // 完成紀錄
  final List<String> _mistakeLogs = [];
  DateTime _sessionStartTime = DateTime.now();

  // 倒數轉場
// ignore: unused_field
  bool _isTransitioning = false;
  DateTime _transitionStartTime = DateTime.now();
  int _lastCountdownSec = -1;
  Timer? _transitionTimer;

  static const double _smoothingFactor = 0.2;

  TurnPalmAction({
    required RehabActionCallback callback,
    this.overlayMirrored = false,
    this.startingLevel = 1,
    this.targetReps = 10,
  }) : super(callback) {
    _startLevel(startingLevel);
  }

  // ── BaseRehabAction ─────────────────────────────────────────────

  @override
  bool get isReadyToReceiveUpdates => _countdownDone;

  @override
  String get initialFeedback => '請握住短棍，對齊虛線保持直立 5 秒';

  @override
  String get initialInstruction => '對齊後保持5秒，才開始計算次數';

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _transitionTimer?.cancel();
  }

  void resetForCameraFlip() {
    if (_countdownDone) return;
    _resetCountdown();
  }

  // ── 主要邏輯 ─────────────────────────────────────────────────────

  @override
  void processLandmarks(List<Landmark> landmarks) {
    if (_pendingLevelUp) return;
    if (landmarks.length < 18) return;

    switch (_currentStage) {
      case _Stage.stage1:
        _detectStage1(landmarks);
        break;
      case _Stage.transitioning:
        // 等 timer 處理
        break;
      case _Stage.stage2:
        _detectStage2(landmarks);
        break;
    }
  }

  // ── 階段一：偵測棍子垂直 ─────────────────────────────────────────

  void _detectStage1(List<Landmark> landmarks) {
    final indexMcp = landmarks[5];
    final pinkyMcp = landmarks[17];

    final indexX = overlayMirrored ? (1.0 - indexMcp.x) : indexMcp.x;
    final pinkyX = overlayMirrored ? (1.0 - pinkyMcp.x) : pinkyMcp.x;

    final dx = indexX - pinkyX;
    final dy = indexMcp.y - pinkyMcp.y;
    final angle = _atan2(dy, dx) * (180 / 3.14159265);
    final deviation = (angle - (-90)).abs();
    final rawDev = deviation > 180 ? 360 - deviation : deviation;

    _smoothedAngleStage1 =
        (_smoothingFactor * rawDev) + ((1 - _smoothingFactor) * _smoothedAngleStage1);
    final displayAngle = _smoothedAngleStage1.toInt();

    callback.onStatsChanged(accuracy: displayAngle.toDouble());

    final wobbleTolerance = _currentLevel == 1 ? 25 : 15;
    final now = DateTime.now();

    if (displayAngle < wobbleTolerance) {
      // 角度合格：清掉「壞幀」計時，代表本次穩定沒有中斷
      _badStartTime = null;
      // 🆕 角度重新合格，允許下次歪掉時可以再播放一次「歪了」
      _hasSpokenTilted = false;

      if (!_isCurrentlyStable) {
        _isCurrentlyStable = true;
        _holdStartTime = now;
        callback.onFeedbackChanged('✅ 很好！穩住棍子', '請出點力，保持直立不要晃動');
        callback.onStatsChanged(repCount: 0, accuracy: displayAngle.toDouble());
        _startCountdown();
      }
      // 完成判定（duration >= 5000ms）現在完全交給 _startCountdown 裡的 Timer
      // 處理，避免這裡跟 Timer 顯示邏輯各算各的、互相對不上。
    } else {
      if (_isCurrentlyStable) {
        // 🆕 給一個容錯緩衝，不要單幀抖動就整個重來
        _badStartTime ??= now;
        final badDuration = now.difference(_badStartTime!).inMilliseconds;

        if (badDuration > _stage1GraceMs) {
          _isCurrentlyStable = false;
          _badStartTime = null;
          _resetCountdown();
        }
        // 還在容錯範圍內：不重置，讓 holdStartTime 繼續累積，
        // 只是這一瞬間角度不合格，不特別提示「歪了」避免畫面閃爍太頻繁。
      } else {
        // 🆕【關鍵修正】文字提示可以每幀更新沒關係（成本低），
        // 但 TTS 語音只在「剛進入歪斜狀態」的那一刻播一次，
        // 避免每幀都呼叫 speak() 塞爆 platform channel 造成畫面卡頓。
        callback.onFeedbackChanged('⚠️ 棍子歪了！', '請拉正短棍，對齊虛線');
        if (!_hasSpokenTilted) {
          _hasSpokenTilted = true;
          HandVoiceService.speak('歪了');
        }
      }
    }
  }

  // ── 倒數（階段一等待，統一由這裡判斷是否完成）──────────────────────

  void _startCountdown() {
    _countdownTimer?.cancel();
    _isCountingDown = true;
    _countdownSeconds = 5;

    callback.onCountdownChanged(
        isCountingDown: true, seconds: _countdownSeconds, isDone: false);

    // 用較短的 tick（100ms）讓畫面更即時，但完成判定一律用真實經過時間，
    // 不再依賴額外一份「duration >= 5000」的判斷邏輯。
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isCurrentlyStable) {
        // 已經在別處被判定失敗並 reset 了，這個 timer 沒事做了
        timer.cancel();
        return;
      }

      final elapsedMs = DateTime.now().difference(_holdStartTime).inMilliseconds;
      final secondsLeft = ((5000 - elapsedMs) / 1000).ceil();
      final displaySeconds = secondsLeft > 0 ? secondsLeft : 0;

      if (displaySeconds != _countdownSeconds) {
        _countdownSeconds = displaySeconds;
        callback.onCountdownChanged(
            isCountingDown: true, seconds: _countdownSeconds, isDone: false);
      }

      if (elapsedMs >= 5000) {
        timer.cancel();
        _isCountingDown = false;
        _isCurrentlyStable = false;
        _badStartTime = null;

        _currentStage = _Stage.transitioning;
        _isTransitioning = true;
        _transitionStartTime = DateTime.now();
        _lastCountdownSec = -1;
        callback.onFeedbackChanged('🎉 穩定度測試通過！', '準備進入翻轉訓練');
        _startTransitionCountdown();
      }
    });
  }

  void _resetCountdown() {
    _countdownTimer?.cancel();
    _isCountingDown = false;
    _countdownSeconds = 5;
    _badStartTime = null;
    // 🆕 重置時也重置語音旗標，避免下一輪卡在「已播過」的狀態
    _hasSpokenTilted = true; // 這裡直接標記為已播，因為下面馬上就會 speak 一次
    callback.onCountdownChanged(
        isCountingDown: false, seconds: 5, isDone: false);
    callback.onFeedbackChanged('棍子歪掉了，重新對齊', '將棍子保持垂直，再次倒數5秒');
    HandVoiceService.speak('歪了');
  }

  // ── 轉場倒數（階段一→階段二） ────────────────────────────────────

  void _startTransitionCountdown() {
    _transitionTimer?.cancel();
    _transitionTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final elapsed =
          DateTime.now().difference(_transitionStartTime).inMilliseconds;

      if (elapsed >= 3000) {
        _transitionTimer?.cancel();
        _isTransitioning = false;
        _currentStage = _Stage.stage2;
        _lastRepTime = DateTime.now();
        _countdownDone = true;
        _pendingState = '';
        _pendingStateCount = 0;
        callback.onCountdownChanged(
            isCountingDown: false, seconds: 0, isDone: true);
        callback.onFeedbackChanged('開始翻掌！', '請握住短棍，輕輕向內轉');
        HandVoiceService.speak('開始');
        callback.onStatsChanged(repCount: 0);
      } else {
        final remain = 3 - (elapsed ~/ 1000);
        if (remain != _lastCountdownSec && remain > 0) {
          _lastCountdownSec = remain;
          callback.onCountdownChanged(
              isCountingDown: true, seconds: remain, isDone: false);
          callback.onFeedbackChanged('⏳ 準備進入階段二', '請在 $remain 秒後開始練習內外轉');
        }
      }
    });
  }

  // ── 階段二：偵測內外翻轉 ─────────────────────────────────────────

  void _detectStage2(List<Landmark> landmarks) {
    final wrist     = landmarks[0];
    final middleMcp = landmarks[9];
    final indexMcp  = landmarks[5];
    final pinkyMcp  = landmarks[17];

    // 晃動偵測
    final wobbleDx = middleMcp.x - wrist.x;
    final wobbleDy = middleMcp.y - wrist.y;
    final wobbleAngle = (_atan2(wobbleDy, wobbleDx) * (180 / 3.14159265) - (-90)).abs();
    final rawWobble = wobbleAngle > 180 ? 360 - wobbleAngle : wobbleAngle;
    if (rawWobble > _currentRepMaxWobble) _currentRepMaxWobble = rawWobble;

    // 🆕 用手掌尺寸（手腕到中指根部的距離）正規化，避免遠近距離影響判定
    final handScale = _distance(wrist, middleMcp);
    final dx = pinkyMcp.x - indexMcp.x;
    final normalizedDx = handScale > 1e-6 ? dx / handScale : 0.0;
    final targetRatio =
        _currentLevel == 1 ? _targetRatioLevel1 : _targetRatioLevel2;

    final rawProgress = normalizedDx.abs() / targetRatio;
    final progress = rawProgress < 1.0 ? rawProgress : 1.0;
    final now = DateTime.now();
    final durationMs = now.difference(_lastRepTime).inMilliseconds;
    final speedState = progress > 0.5 && durationMs < 600 ? 1 : 0;
    callback.onStatsChanged(progress: progress, speedState: speedState);

    final state = normalizedDx > targetRatio
        ? 'OUTWARD'
        : normalizedDx < -targetRatio
            ? 'INWARD'
            : 'NEUTRAL';

    // 🆕 連續同狀態計數，取代原本「8 幀取 5」的多數決，
    // 反應更即時，也不會因為偶爾幾幀被 NEUTRAL 打斷就一直湊不滿。
    if (state == _pendingState) {
      _pendingStateCount++;
    } else {
      _pendingState = state;
      _pendingStateCount = 1;
    }

    final isStableInward =
        state == 'INWARD' && _pendingStateCount >= _requiredConsecutiveFrames;
    final isStableOutward =
        state == 'OUTWARD' && _pendingStateCount >= _requiredConsecutiveFrames;

    if (isStableInward && _lastConfirmedState != 'INWARD') {
      if (_lastConfirmedState == 'OUTWARD') {
        if (durationMs > 1200) {
          _repCount++;
          _lastRepTime = now;
          var score = 100;

          if (_currentRepMaxWobble > 25.0) {
            score -= 20;
            _mistakeLogs.add('第 $_repCount 次：嚴重晃動 (偏移 ${_currentRepMaxWobble.toInt()} 度)');
          } else if (_currentRepMaxWobble > 15.0) {
            score -= 10;
            _mistakeLogs.add('第 $_repCount 次：輕微晃動');
          }
          if (durationMs < 2000) {
            score -= 10;
            _mistakeLogs.add('第 $_repCount 次：動作略快');
          }
          score = score < 60 ? 60 : score;
          _currentRepMaxWobble = 0.0;

          callback.onFeedbackChanged('✅ 完成一次！(本次: $score 分)', '很好，現在請向外轉');
          HandVoiceService.speak('完成一次');
          callback.onStatsChanged(repCount: _repCount);
          callback.onStatsChanged(progress: 0, speedState: 0);

          if (_repCount >= targetReps) {
            if (_currentLevel == 1 && score >= 80) {
              _pendingLevelUp = true;
              callback.onLevelUpReady(nextLevel: 2, nextLevelLabel: '中階 (幅度加大)');
            } else {
              final durationSeconds =
                  DateTime.now().difference(_sessionStartTime).inSeconds;
              callback.onFeedbackChanged('🎉 訓練結束！', '辛苦了');
              HandVoiceService.speak('訓練結束');
              callback.onTrainingComplete(
                repCount: _repCount,
                durationSeconds: durationSeconds,
                mistakeLogs: List.from(_mistakeLogs),
              );
            }
          }
        } else {
          _lastRepTime = now;
          _mistakeLogs.add('未計入次數：動作過快');
          callback.onFeedbackChanged('⚠️ 動作太快', '請慢慢轉動');
          HandVoiceService.speak('太快');
        }
      } else {
        callback.onFeedbackChanged('✅ 已向內轉', '很好，請向外轉');
      }
      _lastConfirmedState = 'INWARD';

    } else if (isStableOutward && _lastConfirmedState != 'OUTWARD') {
      callback.onFeedbackChanged('✅ 已向外轉', '很好，請向內轉');
      _lastConfirmedState = 'OUTWARD';
      callback.onStatsChanged(progress: 0, speedState: 0);
    }

    callback.onStatsChanged(accuracy: dx);
  }

  // ── 關卡切換 ─────────────────────────────────────────────────────

  void _startLevel(int level) {
    _currentLevel = level;
    _repCount = 0;
    _pendingState = '';
    _pendingStateCount = 0;
    _lastConfirmedState = '';
    _currentStage = _Stage.stage1;
    _mistakeLogs.clear();
    _sessionStartTime = DateTime.now();
    _countdownDone = false;
    _isCurrentlyStable = false;
    _badStartTime = null;
    _smoothedAngleStage1 = 0.0;
    _hasSpokenTilted = false; // 🆕 每次重新開始關卡都重置語音旗標

    final diffText = level == 1 ? '初階' : '中階 (幅度加大)';
    callback.onLevelUp(newLevel: level, levelLabel: diffText, newTargetReps: targetReps);
    callback.onFeedbackChanged('$diffText 翻掌', '請握住短棍，對齊虛線保持直立 5 秒');
    callback.onStatsChanged(repCount: 0);
    callback.onCountdownChanged(isCountingDown: false, seconds: 5, isDone: false);
  }

  @override
  bool get isPendingLevelUp => _pendingLevelUp;

  @override
  void confirmLevelUp({int? customTargetReps}) {
    _pendingLevelUp = false;
    if (customTargetReps != null && customTargetReps > 0) {
      targetReps = customTargetReps;
    }
    _startLevel(2);
  }

  @override
  void declineLevelUp() {
    _pendingLevelUp = false;
    final durationSeconds =
        DateTime.now().difference(_sessionStartTime).inSeconds;
    callback.onFeedbackChanged('🎉 訓練結束！', '辛苦了');
    HandVoiceService.speak('訓練結束');
    callback.onTrainingComplete(
      repCount: _repCount,
      durationSeconds: durationSeconds,
      mistakeLogs: List.from(_mistakeLogs),
    );
  }

  // ── 數學工具 ─────────────────────────────────────────────────────

  double _distance(Landmark a, Landmark b) {
    final ddx = a.x - b.x;
    final ddy = a.y - b.y;
    return _sqrt(ddx * ddx + ddy * ddy);
  }

  double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x;
    for (int i = 0; i < 20; i++) {
      guess = 0.5 * (guess + x / guess);
    }
    return guess;
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
        (1 / x) * (pi4 - (1 / x) * ((1 / x).abs() - 1) * (0.2447 + 0.0663 * (1 / x).abs()));
  }
}