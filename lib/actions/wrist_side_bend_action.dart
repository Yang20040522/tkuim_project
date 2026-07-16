// lib/actions/wrist_side_bend_action.dart
//
// 左右彎手腕式 — 中風復健跟著做 第10式
// 雙手手指交扣，由健側手引導換側手腕進行向左與向右的來回彎曲訓練。
// 使用 MediaPipe Hand Landmarks → extends BaseRehabAction

import 'dart:async';
import 'dart:math';
import '../services/mediapipe_service.dart';
import 'base_rehab_action.dart';
import 'rehab_action_callback.dart';
import '../services/hand_voice_service.dart';

class WristSideBendAction extends BaseRehabAction {
  int _repCount = 0;
  bool _isTransitioning = false;
  bool _countdownDone = false;
  final int targetReps;

  final List<String> _stateBuffer = [];
  String _lastConfirmedState = '';

  // 門檻與平滑化參數
  double _smoothedAngle = 0.0;
  static const double _smoothingFactor = 0.2;

  // 動態基準軸（前臂方向）
  double? _baseAngleRad;

  DateTime _lastRepTime = DateTime.now();
  DateTime _sessionStartTime = DateTime.now();
  final List<String> _mistakeLogs = [];

  DateTime _transitionStartTime = DateTime.now();
  int _lastCountdownSec = -1;
  Timer? _transitionTimer;

  // 定義停留計時器（依影片 [00:00:19] 動作到最大角度需停留一陣子）
  DateTime? _stateHoldStartTime;
  bool _hasHeldEnough = false;
  static const int _requiredHoldMs = 1000; // 需在最大角度停留 1 秒

  WristSideBendAction({
    required RehabActionCallback callback,
    this.targetReps = 10,   // ← 新增
  }) : super(callback) {
    _init();
  }

  // ── BaseRehabAction ──────────────────────────────────────

  @override
  bool get isReadyToReceiveUpdates => _countdownDone;

  @override
  String get initialFeedback => '請將雙手手指交扣，健側手準備引導患側手腕左右彎曲';

  @override
  String get initialInstruction => '手腕向左彎到底（停留1秒） → 向右彎到底（停留1秒），算一次';

  @override
  void dispose() {
    _transitionTimer?.cancel();
  }

  // ── 主要邏輯 ─────────────────────────────────────────────

  @override
  void processLandmarks(List<Landmark> landmarks) {
    // 雙手交扣時通常能抓到主要手掌的核心特徵點
    if (landmarks.length < 13) return;
    if (_isTransitioning) return;

    // 使用手腕 (0) 與中指掌指關節 (9) 的連線作為手掌的縱向中軸
    final wrist = landmarks[0];
    final middleMcp = landmarks[9];

    // 計算當前中軸向量與影像水平軸的夾角 (弧度)
    final currentAngleRad = atan2(middleMcp.y - wrist.y, middleMcp.x - wrist.x);

    // 初始化基準軸（在剛開始或接近中立時校準）
    _baseAngleRad ??= currentAngleRad;

    // 計算相對於基準軸的偏角（角度制值）
    double angleDiff = (currentAngleRad - _baseAngleRad!) * 180 / pi;

    // 校正超過 180 度反向切換的問題
    if (angleDiff > 180) angleDiff -= 360;
    if (angleDiff < -180) angleDiff += 360;

    // 低通濾波平滑化數據，避免抖動
    _smoothedAngle = (_smoothingFactor * angleDiff) + ((1 - _smoothingFactor) * _smoothedAngle);

    // 將偏角數據傳回介面（此處將角度作為精確度參考繪製）
    callback.onStatsChanged(accuracy: _smoothedAngle);

    // 設定左右彎曲的角度門檻（根據中風患者交扣引導的合理幅度，定為 15 度）
    const angleThreshold = 15.0;

    // 計算當前動作進度條 (0.0 ~ 1.0)
    final rawProgress = (_smoothedAngle.abs() / angleThreshold).clamp(0.0, 1.0);
    callback.onStatsChanged(progress: rawProgress, speedState: 0);

    // 依據偏角方向判定狀態：
    // 影像座標系中，向左/向右的彎曲會反映在 angleDiff 的正負號上
    String state;
    if (_smoothedAngle > angleThreshold) {
      state = 'LEFT';
    } else if (_smoothedAngle < -angleThreshold) {
      state = 'RIGHT';
    } else if (_smoothedAngle.abs() < 5.0) {
      state = 'NEUTRAL';
    } else {
      state = 'BENDING';
    }

    // 狀態緩衝區去雜訊
    _stateBuffer.add(state);
    if (_stateBuffer.length > 6) _stateBuffer.removeAt(0);

    final isStableLeft = _stateBuffer.where((s) => s == 'LEFT').length >= 4;
    final isStableRight = _stateBuffer.where((s) => s == 'RIGHT').length >= 4;

    // ───────────────── 狀態機與影片動作要領判定 ─────────────────
    
    if (isStableLeft && _lastConfirmedState != 'LEFT') {
      // 處理向左彎曲到位
      if (_stateHoldStartTime == null || _lastConfirmedState != 'HOLD_LEFT') {
        _stateHoldStartTime = DateTime.now();
        _hasHeldEnough = false;
        callback.onFeedbackChanged('➔ 向左彎曲到位！', '請保持停留在最大角度...');
      }

      final holdDuration = DateTime.now().difference(_stateHoldStartTime!).inMilliseconds;
      if (holdDuration >= _requiredHoldMs && !_hasHeldEnough) {
        _hasHeldEnough = true;
        
        // 如果上一個完成的完整動作是右彎，則此時可計入一次完整來回
        if (_lastConfirmedState == 'RIGHT_DONE') {
          final now = DateTime.now();
          final durationMs = now.difference(_lastRepTime).inMilliseconds;

          if (durationMs > 1500) {
            _repCount++;
            _lastRepTime = now;
            var score = 100;

            // 動作過慢判定 (超過 5 秒未換側)
            if (durationMs > 5000) {
              score -= 10;
              _mistakeLogs.add('第 $_repCount 次：換側引導速度較慢');
            }
            // 幅度邊緣判定
            if (_smoothedAngle < angleThreshold * 1.1) {
              score -= 5;
              _mistakeLogs.add('第 $_repCount 次：左彎幅度可再加大');
            }

            callback.onFeedbackChanged(
              '✅ 完成一組左右來回！(本次得分: $score 分)',
              '很好，接下來請再向右彎',
            );
            HandVoiceService.speak('完成一次');
            callback.onStatsChanged(repCount: _repCount);

            if (_repCount >= targetReps) _finish();
          } else {
            _mistakeLogs.add('未計入：左右切換速度過快，未達復健擴展效果');
            callback.onFeedbackChanged('⚠️ 動作太快', '請依建側手慢慢引導，穩定擺動');
            HandVoiceService.speak('太快');
          }
          _lastConfirmedState = 'LEFT_DONE';
        } else {
          // 剛啟動動作或從中立點過來
          callback.onFeedbackChanged('✅ 左彎停留完成', '接著請慢速向右彎擺');
          _lastConfirmedState = 'LEFT_DONE';
        }
        _stateHoldStartTime = null; // 重置停留計時
      }
    } 
    else if (isStableRight && _lastConfirmedState != 'RIGHT') {
      // 處理向右彎曲到位
      if (_stateHoldStartTime == null || _lastConfirmedState != 'HOLD_RIGHT') {
        _stateHoldStartTime = DateTime.now();
        _hasHeldEnough = false;
        callback.onFeedbackChanged('➔ 向右彎曲到位！', '請保持停留在最大角度...');
      }

      final holdDuration = DateTime.now().difference(_stateHoldStartTime!).inMilliseconds;
      if (holdDuration >= _requiredHoldMs && !_hasHeldEnough) {
        _hasHeldEnough = true;

        if (_lastConfirmedState == 'LEFT_DONE') {
          final now = DateTime.now();
          final durationMs = now.difference(_lastRepTime).inMilliseconds;

          if (durationMs > 1500) {
            _repCount++;
            _lastRepTime = now;
            var score = 100;

            if (durationMs > 5000) {
              score -= 10;
              _mistakeLogs.add('第 $_repCount 次：右彎擺動引導偏慢');
            }
            if (_smoothedAngle.abs() < angleThreshold * 1.1) {
              score -= 5;
              _mistakeLogs.add('第 $_repCount 次：右彎幅度可再加深');
            }

            callback.onFeedbackChanged(
              '✅ 完成一組左右來回！(本次得分: $score 分)',
              '做得好！接下來再向左彎',
            );
            HandVoiceService.speak('完成一次');
            callback.onStatsChanged(repCount: _repCount);

            if (_repCount >= 10) _finish();
          } else {
            _mistakeLogs.add('未計入：換側速度過急');
            callback.onFeedbackChanged('⚠️ 擺動太快', '請放慢速度，體會關卡延展');
            HandVoiceService.speak('太快');
          }
          _lastConfirmedState = 'RIGHT_DONE';
        } else {
          callback.onFeedbackChanged('✅ 右彎停留完成', '接著請慢速向左彎擺');
          _lastConfirmedState = 'RIGHT_DONE';
        }
        _stateHoldStartTime = null;
      }
    }
    else if (state == 'NEUTRAL' && _lastConfirmedState == '') {
      // 自動校準中立基準點
      _baseAngleRad = currentAngleRad;
    }
  }

  // ── 私有邏輯 ─────────────────────────────────────────────

  void _init() {
    _isTransitioning = true;
    _countdownDone = false;
    _transitionStartTime = DateTime.now();
    _lastCountdownSec = -1;
    _sessionStartTime = DateTime.now();

    callback.onFeedbackChanged('左右彎手腕訓練', '準備進入關卡...');
    callback.onStatsChanged(repCount: 0);

    _transitionTimer?.cancel();
    _transitionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = DateTime.now().difference(_transitionStartTime).inMilliseconds;

      if (elapsed < 3000) {
        final remain = 3 - (elapsed ~/ 1000);
        if (remain != _lastCountdownSec && remain > 0) {
          _lastCountdownSec = remain;
          callback.onCountdownChanged(isCountingDown: true, seconds: remain, isDone: false);
        }
      } else {
        _transitionTimer?.cancel();
        _isTransitioning = false;
        _countdownDone = true;
        _lastRepTime = DateTime.now();
        callback.onCountdownChanged(isCountingDown: false, seconds: 0, isDone: true);
        callback.onFeedbackChanged(
          '開始！請由健側手帶領換側手擺動',
          '向左彎到底停留 ➔ 向右彎到底停留，算一次',
        );
      }
    });
  }

  void _finish() {
    final durationSeconds = DateTime.now().difference(_sessionStartTime).inSeconds;
    callback.onFeedbackChanged('🎉 完成 10 次手腕左右彎擺！', '辛苦了，手腕復健表現得很好！');
    callback.onTrainingComplete(
      repCount: _repCount,
      durationSeconds: durationSeconds,
      mistakeLogs: List.from(_mistakeLogs),
    );
  }
}