// lib/actions/draw_circle_action.dart
//
// 畫圓訓練 — 判定邏輯。implements BodyRehabAction,可直接丟進 body_training_screen。

import 'dart:math' as math;
import '../models/body_frame.dart';
import 'body_rehab_action.dart';
import 'wipe_body_action.dart' show RehabDifficulty; // 共用同一個難度 enum

class DrawCircleAction implements BodyRehabAction {
  RehabDifficulty difficulty;
  int successCount = 0;
  final int targetCount = 3;

  double _sweptAngle = 0.0;
  double _lastAngle = double.nan;

  RehabJoint? _activeWrist;
  RehabJoint? _activeShoulder;

  DateTime _lastVoiceTime = DateTime.now();

  DrawCircleAction({this.difficulty = RehabDifficulty.easy});

  // ── 合約要求 ──────────────────────────────────────────────
  @override
  String get title => '畫圓訓練';

  @override
  String get initialHint => '舉起一隻手,準備畫大圓';

  @override
  String get difficultyLabel {
    switch (difficulty) {
      case RehabDifficulty.easy:
        return '初級';
      case RehabDifficulty.medium:
        return '中級';
      case RehabDifficulty.hard:
        return '高級';
    }
  }

  // ── 合約核心:每幀判定 ────────────────────────────────────
  @override
  RehabFeedback update(BodyFrame frame) {
    final leftShoulder = frame.joints[RehabJoint.leftShoulder];
    final rightShoulder = frame.joints[RehabJoint.rightShoulder];
    final leftWrist = frame.joints[RehabJoint.leftWrist];
    final rightWrist = frame.joints[RehabJoint.rightWrist];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftWrist == null ||
        rightWrist == null) {
      return RehabFeedback.none;
    }

    // 1. 自動偵測活躍手
    if (_activeWrist == null) {
      if (leftWrist.dy < leftShoulder.dy) {
        _activeWrist = RehabJoint.leftWrist;
        _activeShoulder = RehabJoint.leftShoulder;
        return RehabFeedback(prompt: _speakThrottled('已鎖定左手,請開始畫大圓'));
      } else if (rightWrist.dy < rightShoulder.dy) {
        _activeWrist = RehabJoint.rightWrist;
        _activeShoulder = RehabJoint.rightShoulder;
        return RehabFeedback(prompt: _speakThrottled('已鎖定右手,請開始畫大圓'));
      }
      return RehabFeedback.none;
    }

    // 2. 取活躍手座標
    final shoulder = frame.joints[_activeShoulder!];
    final wrist = frame.joints[_activeWrist!];
    if (shoulder == null || wrist == null) return RehabFeedback.none;

    // 3. 計算半徑 (防代償)
    final dx = wrist.dx - shoulder.dx;
    final dy = wrist.dy - shoulder.dy;
    final radius = math.sqrt(dx * dx + dy * dy);
    final requiredRadius =
        (difficulty == RehabDifficulty.easy) ? 0.25 : 0.35;

    if (radius < requiredRadius) {
      _lastAngle = double.nan;
      return RehabFeedback(prompt: _speakThrottled('手臂請伸直,畫大一點的圓'));
    }

    // 4. 累積角度
    final currentAngle = math.atan2(dy, dx) * (180 / math.pi);

    if (!_lastAngle.isNaN) {
      double deltaAngle = currentAngle - _lastAngle;
      if (deltaAngle > 180) deltaAngle -= 360;
      if (deltaAngle < -180) deltaAngle += 360;
      _sweptAngle += deltaAngle.abs();

      // 5. 完成一圈
      if (_sweptAngle >= 360.0) {
        _sweptAngle = 0.0;
        successCount++;

        if (successCount >= targetCount) {
          _upgradeDifficulty();
          return const RehabFeedback(
            prompt: '太棒了!解鎖下一個難度!',
            scored: true,
            leveledUp: true,
          );
        }
        _lastAngle = currentAngle;
        return const RehabFeedback(
          prompt: '完成一圈!請繼續畫',
          scored: true,
        );
      }
    }
    _lastAngle = currentAngle;

    return RehabFeedback.none;
  }

  // ── 私有 ──────────────────────────────────────────────────
  String? _speakThrottled(String text) {
    final now = DateTime.now();
    if (now.difference(_lastVoiceTime).inSeconds > 2) {
      _lastVoiceTime = now;
      return text;
    }
    return null;
  }

  void _upgradeDifficulty() {
    successCount = 0;
    _sweptAngle = 0.0;
    _lastAngle = double.nan;
    if (difficulty == RehabDifficulty.easy) {
      difficulty = RehabDifficulty.medium;
    } else if (difficulty == RehabDifficulty.medium) {
      difficulty = RehabDifficulty.hard;
    }
  }
}