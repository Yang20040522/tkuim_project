// lib/actions/raise_both_arms_action.dart
//
// 雙手抬舉式 — 中風復健跟著做 第3式
// 好手交扣患手，雙手一起往上抬舉過肩
// 使用 RTMPose 全身骨架 → implements BodyRehabAction

import 'dart:math' as math;
import '../models/body_frame.dart';
import 'body_rehab_action.dart';
import 'wipe_body_action.dart' show RehabDifficulty;

enum _RaiseState { waitReady, raising, holding, lowering }

class RaiseBothArmsAction implements BodyRehabAction {
  RehabDifficulty difficulty;
  int successCount = 0;
  final int targetCount = 10;

  _RaiseState _state = _RaiseState.waitReady;
  DateTime _lastVoiceTime = DateTime.now();
  DateTime _lastRepTime = DateTime.now();
  DateTime _holdStartTime = DateTime.now();
  DateTime _lowerStartTime = DateTime.now(); // ✅ 新增：記錄開始放下的時間

  final List<String> _mistakeLogs = [];
  final DateTime _sessionStartTime = DateTime.now();

  RaiseBothArmsAction({this.difficulty = RehabDifficulty.easy});

  // ── 合約要求 ──────────────────────────────────────────────

  @override
  String get title => '雙手抬舉式';

  @override
  String get initialHint => '雙手交扣，自然垂放，準備往上抬舉';

  @override
  String get difficultyLabel => '標準';

  // ── 合約核心：每幀判定 ────────────────────────────────────

  @override
  RehabFeedback update(BodyFrame frame) {
    final leftShoulder  = frame.joints[RehabJoint.leftShoulder];
    final rightShoulder = frame.joints[RehabJoint.rightShoulder];
    final leftWrist     = frame.joints[RehabJoint.leftWrist];
    final rightWrist    = frame.joints[RehabJoint.rightWrist];
    final leftHip       = frame.joints[RehabJoint.leftHip];
    final rightHip      = frame.joints[RehabJoint.rightHip];

    if (leftShoulder == null  ||
        rightShoulder == null ||
        leftWrist == null     ||
        rightWrist == null    ||
        leftHip == null       ||
        rightHip == null) {
      return RehabFeedback.none;
    }

    // 軀幹高度基準（影像座標：y 越大 = 越低）
    final shoulderMidY = (leftShoulder.dy + rightShoulder.dy) / 2;
    final hipMidY      = (leftHip.dy + rightHip.dy) / 2;

    // 防後仰借力
    final leftSpineDx  = leftShoulder.dx - leftHip.dx;
    final leftSpineDy  = leftShoulder.dy - leftHip.dy;
    final spineAngle   = math.atan2(leftSpineDx, leftSpineDy) * (180 / math.pi);
    if (spineAngle.abs() > 20) {
      return RehabFeedback(prompt: _throttle('請坐正，不要後仰借力'));
    }

    // 雙手腕平均高度
    final wristMidY = (leftWrist.dy + rightWrist.dy) / 2;

    // 防聳肩：雙肩高度差
    final shoulderDiff = (leftShoulder.dy - rightShoulder.dy).abs();
    if (shoulderDiff > 0.07 && _state == _RaiseState.raising) {
      _mistakeLogs.add('第 $successCount 次：聳肩代償');
      return RehabFeedback(prompt: _throttle('放鬆肩膀，不要聳肩'));
    }

    // 高度定義（y 越小 = 越高）
    final targetY   = shoulderMidY - 0.08; // 手腕需高於肩膀 0.08 才算抬到位
    final restingY  = hipMidY + 0.05;      // ✅ 手腕低於髖部 = 已放回備妥位置

    final now = DateTime.now();

    switch (_state) {
      case _RaiseState.waitReady:
        // ✅ 修正：wristMidY > restingY 代表手腕比 restingY 還低（更靠近腳）
        // 即手自然垂放在腿上，才觸發「預備好」
        if (wristMidY > restingY) {
          _state = _RaiseState.raising;
          return RehabFeedback(prompt: _throttle('預備好了！雙手交扣往上抬'));
        }
        break;

      case _RaiseState.raising:
        // 手腕高於目標高度（y 更小）才算抬到位
        if (wristMidY < targetY) {
          _state = _RaiseState.holding;
          _holdStartTime = now; // ✅ 每次進入 holding 都重新計時
          return RehabFeedback(prompt: _throttle('很好！撐住 2 秒'));
        }
        break;

      case _RaiseState.holding:
        // ✅ 修正：手掉下來就重置 holdStartTime，防止累積計時
        if (wristMidY > targetY + 0.06) {
          _state = _RaiseState.raising;
          _holdStartTime = now; // ✅ 重置，避免再抬上來時殘留舊計時
          return RehabFeedback(prompt: _throttle('手掉下來了，再往上抬高'));
        }
        if (now.difference(_holdStartTime).inSeconds >= 2) {
          _state = _RaiseState.lowering;
          _lowerStartTime = now; // ✅ 記錄開始放下的時間點
          return RehabFeedback(prompt: _throttle('非常好！慢慢放下來'));
        }
        break;

      case _RaiseState.lowering:
        // 手腕放回備妥位置（y 夠大）才算放下完成
        if (wristMidY > restingY) {
          // ✅ 修正：用 lowerStartTime 計算放下花了多久，才是「放太快」的正確判斷
          final lowerDurationMs = now.difference(_lowerStartTime).inMilliseconds;
          // ✅ 修正：用 lastRepTime 防止同一次動作重複計分（最少間隔 1500ms）
          final repIntervalMs = now.difference(_lastRepTime).inMilliseconds;

          if (repIntervalMs > 1500) {
            if (lowerDurationMs < 800) {
              // 放下太快（不到 0.8 秒就放到底）
              _lastRepTime = now;
              _state = _RaiseState.waitReady;
              _mistakeLogs.add('第 $successCount 次：放下太快');
              return RehabFeedback(prompt: _throttle('放太快了！用肌肉慢慢控制放下'));
            }

            successCount++;
            _lastRepTime = now;
            _state = _RaiseState.waitReady; // ✅ 修正：回到 waitReady，讓使用者先穩定再抬

            if (successCount >= targetCount) {
              return RehabFeedback(
                prompt: '🎉 完成 $targetCount 次！訓練結束，辛苦了！',
                scored: true,
                leveledUp: true,
              );
            }
            return const RehabFeedback(
              prompt: '完成一次！繼續往上抬',
              scored: true,
            );
          }
        }
        break;
    }

    return RehabFeedback.none;
  }

  // ── 私有 ──────────────────────────────────────────────────

  String? _throttle(String text) {
    final now = DateTime.now();
    if (now.difference(_lastVoiceTime).inSeconds > 2) {
      _lastVoiceTime = now;
      return text;
    }
    return null;
  }
}