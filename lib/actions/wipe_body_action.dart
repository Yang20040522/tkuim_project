// lib/actions/wipe_body_action.dart
//
// 功能性擦拭訓練 — 判定邏輯。
// implements BodyRehabAction,可直接丟進 body_training_screen。

import 'dart:math' as math;
import '../models/body_frame.dart';
import 'body_rehab_action.dart';

enum RehabDifficulty { easy, medium, hard }

class WipeBodyAction implements BodyRehabAction {
  RehabDifficulty difficulty;
  int successCount = 0;
  final int targetCount = 3;

  bool _hasTriggeredWipe = false;
  DateTime _lastVoiceTime = DateTime.now();

  WipeBodyAction({this.difficulty = RehabDifficulty.easy});

  // ── 合約要求 ──────────────────────────────────────────────
  @override
  String get title => '功能性擦拭訓練';

  @override
  String get initialHint => '雙手自然垂放,準備進行功能性擦拭訓練';

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
    final leftElbow = frame.joints[RehabJoint.leftElbow];
    final leftWrist = frame.joints[RehabJoint.leftWrist];
    final leftHip = frame.joints[RehabJoint.leftHip];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        leftWrist == null ||
        leftHip == null) {
      return RehabFeedback.none;
    }

    // 防聳肩
    final shoulderDrop = (leftShoulder.dy - rightShoulder.dy).abs();
    final maxShoulderTolerance =
        (difficulty == RehabDifficulty.easy) ? 0.08 : 0.05;
    if (shoulderDrop > maxShoulderTolerance) {
      return RehabFeedback(prompt: _speakThrottled('請放下肩膀,不要聳肩喔'));
    }

    // 防後仰
    final spineDx = leftShoulder.dx - leftHip.dx;
    final spineDy = leftShoulder.dy - leftHip.dy;
    final spineAngle = math.atan2(spineDx, spineDy) * (180 / math.pi);
    if (spineAngle < -15) {
      return RehabFeedback(prompt: _speakThrottled('坐正一點,身體微微前傾'));
    }

    // 手肘角度
    final elbowAngle = _calculateAngle(leftShoulder, leftElbow, leftWrist);
    final minElbowAngle =
        (difficulty == RehabDifficulty.hard) ? 140.0 : 120.0;

    // 目標區判定
    bool isInTargetZone = false;
    switch (difficulty) {
      case RehabDifficulty.easy:
        isInTargetZone = leftWrist.dy > leftHip.dy &&
            (leftWrist.dx - leftHip.dx).abs() < 0.2;
        break;
      case RehabDifficulty.medium:
        isInTargetZone =
            leftWrist.dy < leftHip.dy && leftWrist.dy > leftShoulder.dy;
        break;
      case RehabDifficulty.hard:
        isInTargetZone = leftWrist.dy < leftShoulder.dy &&
            elbowAngle >= minElbowAngle;
        break;
    }

    // 計分與跳關
    if (isInTargetZone && elbowAngle >= minElbowAngle) {
      if (!_hasTriggeredWipe) {
        _hasTriggeredWipe = true;
        successCount++;

        if (successCount >= targetCount) {
          _upgradeDifficulty();
          return const RehabFeedback(
            prompt: '太棒了!解鎖下一個難度!',
            scored: true,
            leveledUp: true,
          );
        }
        return const RehabFeedback(
          prompt: '動作標準,擦得很好!',
          scored: true,
        );
      }
    } else if (!isInTargetZone && leftWrist.dy > leftShoulder.dy) {
      _hasTriggeredWipe = false;
    }

    if (isInTargetZone && elbowAngle < minElbowAngle) {
      return RehabFeedback(prompt: _speakThrottled('手肘試著再伸直一點'));
    }

    return RehabFeedback.none;
  }

  // ── 私有 ──────────────────────────────────────────────────
  double _calculateAngle(dynamic p1, dynamic p2, dynamic p3) {
    final a = math.sqrt(
        math.pow(p2.dx - p3.dx, 2) + math.pow(p2.dy - p3.dy, 2));
    final b = math.sqrt(
        math.pow(p1.dx - p3.dx, 2) + math.pow(p1.dy - p3.dy, 2));
    final c = math.sqrt(
        math.pow(p1.dx - p2.dx, 2) + math.pow(p1.dy - p2.dy, 2));
    if (a * c == 0) return 0.0;
    final cosB =
        (math.pow(a, 2) + math.pow(c, 2) - math.pow(b, 2)) / (2 * a * c);
    return math.acos(cosB.clamp(-1.0, 1.0)) * (180 / math.pi);
  }

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
    _hasTriggeredWipe = false;
    if (difficulty == RehabDifficulty.easy) {
      difficulty = RehabDifficulty.medium;
    } else if (difficulty == RehabDifficulty.medium) {
      difficulty = RehabDifficulty.hard;
    }
  }
}