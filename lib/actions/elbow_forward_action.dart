// lib/actions/elbow_forward_action.dart
//
// 交扣手肘前伸式 — 中風復健跟著做 第8式
// 雙手十指交扣，手肘向前伸直推出
// 使用 RTMPose 全身骨架 → implements BodyRehabAction

import 'dart:math' as math;
import '../models/body_frame.dart';
import 'body_rehab_action.dart';
import 'wipe_body_action.dart' show RehabDifficulty;

enum _ElbowState { waitReady, extending, holding, retracting }

class ElbowForwardAction implements BodyRehabAction {
  RehabDifficulty difficulty;
  int successCount = 0;
  final int targetCount = 10;

  _ElbowState _state = _ElbowState.waitReady;
  DateTime _lastVoiceTime = DateTime.now();
  DateTime _lastRepTime = DateTime.now();
  DateTime _holdStartTime = DateTime.now();
  DateTime _retractStartTime = DateTime.now(); // ✅ 新增：記錄開始收回的時間

  final List<String> _mistakeLogs = [];
  final DateTime _sessionStartTime = DateTime.now();

  ElbowForwardAction({this.difficulty = RehabDifficulty.easy});

  // ── 合約要求 ──────────────────────────────────────────────

  @override
  String get title => '交扣手肘前伸式';

  @override
  String get initialHint => '雙手十指交扣放在胸前，準備向前推出';

  @override
  String get difficultyLabel => '標準';

  // ── 合約核心：每幀判定 ────────────────────────────────────

  @override
  RehabFeedback update(BodyFrame frame) {
    final leftShoulder  = frame.joints[RehabJoint.leftShoulder];
    final rightShoulder = frame.joints[RehabJoint.rightShoulder];
    final leftElbow     = frame.joints[RehabJoint.leftElbow];
    final rightElbow    = frame.joints[RehabJoint.rightElbow];
    final leftWrist     = frame.joints[RehabJoint.leftWrist];
    final rightWrist    = frame.joints[RehabJoint.rightWrist];
    final leftHip       = frame.joints[RehabJoint.leftHip];

    if (leftShoulder == null  ||
        rightShoulder == null ||
        leftElbow == null     ||
        rightElbow == null    ||
        leftWrist == null     ||
        rightWrist == null    ||
        leftHip == null) {
      return RehabFeedback.none;
    }

    // 防後仰借力
    final spineDx    = leftShoulder.dx - leftHip.dx;
    final spineDy    = leftShoulder.dy - leftHip.dy;
    final spineAngle = math.atan2(spineDx, spineDy) * (180 / math.pi);
    if (spineAngle < -20) {
      return RehabFeedback(prompt: _throttle('坐直一點，不要往後靠'));
    }

    // 防聳肩（只在推出過程中偵測）
    final shoulderDiff = (leftShoulder.dy - rightShoulder.dy).abs();
    if (shoulderDiff > 0.07 && _state == _ElbowState.extending) {
      _mistakeLogs.add('第 $successCount 次：聳肩');
      return RehabFeedback(prompt: _throttle('放鬆肩膀，不要聳肩'));
    }

    // 計算左右手肘角度（越接近 180 度 = 越伸直）
    final leftElbowAngle  = _angle(leftShoulder, leftElbow, leftWrist);
    final rightElbowAngle = _angle(rightShoulder, rightElbow, rightWrist);
    final avgElbowAngle   = (leftElbowAngle + rightElbowAngle) / 2;

    final wristMidY    = (leftWrist.dy + rightWrist.dy) / 2;
    final shoulderMidY = (leftShoulder.dy + rightShoulder.dy) / 2;

    // 前伸到位：手肘角度 > 140 度，且手腕高度接近肩膀（水平推出）
    final isExtended = avgElbowAngle > 140 &&
        (wristMidY - shoulderMidY).abs() < 0.15;

    // 收回到位：手肘角度 < 100 度（手交扣放在胸前）
    final isRetracted = avgElbowAngle < 100;

    final now = DateTime.now();

    switch (_state) {
      case _ElbowState.waitReady:
        // ✅ 修正：等手肘先彎曲收在胸前，再確認一次才觸發
        // 避免一啟動就直接進 extending
        // 用 isRetracted 確認使用者手已放好
        if (isRetracted) {
          // 額外防呆：至少停在收回狀態 0.5 秒才算備妥
          // 用 _lastRepTime 當臨時計時（初始值是 DateTime.now()，第一次一定通過）
          final readyDuration = now.difference(_lastRepTime).inMilliseconds;
          if (readyDuration > 500) {
            _state = _ElbowState.extending;
            return RehabFeedback(prompt: _throttle('預備好！雙手交扣向前推出'));
          }
        }
        break;

      case _ElbowState.extending:
        if (isExtended) {
          _state = _ElbowState.holding;
          _holdStartTime = now; // ✅ 每次進入 holding 重新計時
          return RehabFeedback(prompt: _throttle('很好！撐住 2 秒'));
        }
        break;

      case _ElbowState.holding:
        // ✅ 修正：手沒撐住就重置 holdStartTime，防累積
        if (!isExtended && avgElbowAngle < 120) {
          _state = _ElbowState.extending;
          _holdStartTime = now; // ✅ 重置，避免殘留舊計時
          return RehabFeedback(prompt: _throttle('手收回來了，再往前推直'));
        }
        if (now.difference(_holdStartTime).inSeconds >= 2) {
          _state = _ElbowState.retracting;
          _retractStartTime = now; // ✅ 記錄開始收回的時間點
          return RehabFeedback(prompt: _throttle('很棒！慢慢收回胸前'));
        }
        break;

      case _ElbowState.retracting:
        if (isRetracted) {
          // ✅ 修正：用 retractStartTime 判斷「收回速度」，不是 lastRepTime
          final retractDurationMs = now.difference(_retractStartTime).inMilliseconds;
          // ✅ 修正：用 lastRepTime 防止同一次重複計分
          final repIntervalMs = now.difference(_lastRepTime).inMilliseconds;

          if (repIntervalMs > 1500) {
            if (retractDurationMs < 600) {
              // 收回太快（不到 0.6 秒就收到底）
              _lastRepTime = now;
              _state = _ElbowState.waitReady;
              _mistakeLogs.add('第 $successCount 次：收回太快');
              return RehabFeedback(prompt: _throttle('收太快了！慢慢控制收回'));
            }

            successCount++;
            _lastRepTime = now;
            _state = _ElbowState.waitReady; // ✅ 修正：回 waitReady，給使用者穩定空間

            if (successCount >= targetCount) {
              return RehabFeedback(
                prompt: '🎉 完成 $targetCount 次！訓練結束，辛苦了！',
                scored: true,
                leveledUp: true,
              );
            }
            return const RehabFeedback(
              prompt: '完成一次！繼續往前伸',
              scored: true,
            );
          }
        }
        break;
    }

    return RehabFeedback.none;
  }

  // ── 私有 ──────────────────────────────────────────────────

  double _angle(dynamic p1, dynamic p2, dynamic p3) {
    final a = math.sqrt(math.pow(p2.dx - p3.dx, 2) + math.pow(p2.dy - p3.dy, 2));
    final b = math.sqrt(math.pow(p1.dx - p3.dx, 2) + math.pow(p1.dy - p3.dy, 2));
    final c = math.sqrt(math.pow(p1.dx - p2.dx, 2) + math.pow(p1.dy - p2.dy, 2));
    if (a * c == 0) return 0.0;
    final cosB = (math.pow(a, 2) + math.pow(c, 2) - math.pow(b, 2)) / (2 * a * c);
    return math.acos(cosB.clamp(-1.0, 1.0)) * (180 / math.pi);
  }

  String? _throttle(String text) {
    final now = DateTime.now();
    if (now.difference(_lastVoiceTime).inSeconds > 2) {
      _lastVoiceTime = now;
      return text;
    }
    return null;
  }
}