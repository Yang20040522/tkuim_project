// lib/actions/standing_knee_raise_action.dart
//
// 站姿抬腳式訓練 — 判定邏輯。
// implements BodyRehabAction, 可直接丟進 body_training_screen。

import 'dart:math' as math;
import '../models/body_frame.dart';
import 'body_rehab_action.dart';

// enum RehabDifficulty { easy, medium, hard }

class StandingKneeRaiseAction implements BodyRehabAction {
  RehabDifficulty difficulty;
  int successCount = 0;
  final int targetCount = 3;

  bool _hasTriggeredRaise = false;
  DateTime _lastVoiceTime = DateTime.now();

  // 以左腳為主要換側抬腳範例，可根據需求動態調整
  StandingKneeRaiseAction({this.difficulty = RehabDifficulty.easy});

  // ── 合約要求 ──────────────────────────────────────────────
  @override
  String get title => '站姿抬腳式訓練';

  @override
  String get initialHint => '雙腳與肩同寬站立，手扶椅背或拐杖，準備進行抬腳訓練';

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

  // ── 合約核心: 每幀判定 ────────────────────────────────────
  @override
  RehabFeedback update(BodyFrame frame) {
    // 取得上半身骨架（防代償用）
    final leftShoulder = frame.joints[RehabJoint.leftShoulder];
    final rightShoulder = frame.joints[RehabJoint.rightShoulder];
    
    // 取得下半身骨架（動作判定用，以左腳為患側抬腿為例）
    final leftHip = frame.joints[RehabJoint.leftHip];
    final leftKnee = frame.joints[RehabJoint.leftKnee];
    final leftAnkle = frame.joints[RehabJoint.leftAnkle];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        leftKnee == null ||
        leftAnkle == null) {
      return RehabFeedback.none;
    }

    // 1. 防代償：防過度傾斜/聳肩 (保持兩側肩膀水平)
    final shoulderDrop = (leftShoulder.dy - rightShoulder.dy).abs();
    final maxShoulderTolerance = (difficulty == RehabDifficulty.easy) ? 0.08 : 0.05;
    if (shoulderDrop > maxShoulderTolerance) {
      return RehabFeedback(prompt: _speakThrottled('請保持身體直立，不要歪斜或聳肩喔'));
    }

    // 2. 防代償：防身體後仰
    final spineDx = leftShoulder.dx - leftHip.dx;
    final spineDy = leftShoulder.dy - leftHip.dy;
    final spineAngle = math.atan2(spineDx, spineDy) * (180 / math.pi);
    if (spineAngle < -15) {
      return RehabFeedback(prompt: _speakThrottled('站直一點，身體不要往後仰'));
    }

    // 3. 計算關節角度
    // 髖關節角度（大腿與軀幹的夾角）：利用肩膀、髖部、膝蓋計算
    final hipAngle = _calculateAngle(leftShoulder, leftHip, leftKnee);
    // 膝關節彎曲角度：利用髖部、膝蓋、腳踝計算
    final kneeAngle = _calculateAngle(leftHip, leftKnee, leftAnkle);

    // 4. 目標區與難度判定
    bool isInTargetZone = false;
    
    switch (difficulty) {
      case RehabDifficulty.easy:
        // 初級：大腿微抬，膝蓋高於腳踝，髖關節彎曲角度（小於 140 度即可）
        isInTargetZone = leftKnee.dy < leftHip.dy && hipAngle < 140.0;
        break;
      case RehabDifficulty.medium:
        // 中級（影片標準）：大腿抬平接近 90 度（hipAngle 約 90-110 度），且膝蓋自然彎曲（kneeAngle 約 80-110 度）
        isInTargetZone = leftKnee.dy < leftHip.dy && 
                         hipAngle <= 110.0 && 
                         kneeAngle >= 80.0 && kneeAngle <= 110.0;
        break;
      case RehabDifficulty.hard:
        // 高級：大腿抬得更高（hipAngle < 90 度），且膝蓋能精準控制在約 90 度，停留更穩定
        isInTargetZone = leftKnee.dy < leftHip.dy && 
                         hipAngle < 90.0 && 
                         kneeAngle >= 85.0 && kneeAngle <= 100.0;
        break;
    }

    // 5. 計分與跳關邏輯
    if (isInTargetZone) {
      if (!_hasTriggeredRaise) {
        _hasTriggeredRaise = true;
        successCount++;

        if (successCount >= targetCount) {
          _upgradeDifficulty();
          return const RehabFeedback(
            prompt: '太棒了！動作非常標準，解鎖下一個難度！',
            scored: true,
            leveledUp: true,
          );
        }
        return const RehabFeedback(
          prompt: '慢抬慢放，做得很好！',
          scored: true,
        );
      }
    } else if (leftKnee.dy > leftHip.dy + 0.1) {
      // 當膝蓋放低，回到接近原起始站姿時，重置觸發開關，允許下一次計分
      _hasTriggeredRaise = false;
    }

    // 6. 即時動態提示
    if (!isInTargetZone && _hasTriggeredRaise == false) {
      if (difficulty == RehabDifficulty.medium && hipAngle > 110.0) {
        return RehabFeedback(prompt: _speakThrottled('試著把膝蓋再抬高，靠近肚子一點'));
      }
      if (kneeAngle < 70.0 || kneeAngle > 120.0) {
        return RehabFeedback(prompt: _speakThrottled('保持小腿自然下垂，膝蓋彎曲約90度'));
      }
    }

    return RehabFeedback.none;
  }

  // ── 私有方法 ──────────────────────────────────────────────
  double _calculateAngle(dynamic p1, dynamic p2, dynamic p3) {
    final a = math.sqrt(math.pow(p2.dx - p3.dx, 2) + math.pow(p2.dy - p3.dy, 2));
    final b = math.sqrt(math.pow(p1.dx - p3.dx, 2) + math.pow(p1.dy - p3.dy, 2));
    final c = math.sqrt(math.pow(p1.dx - p2.dx, 2) + math.pow(p1.dy - p2.dy, 2));
    if (a * c == 0) return 0.0;
    final cosB = (math.pow(a, 2) + math.pow(c, 2) - math.pow(b, 2)) / (2 * a * c);
    return math.acos(cosB.clamp(-1.0, 1.0)) * (180 / math.pi);
  }

  String? _speakThrottled(String text) {
    final now = DateTime.now();
    if (now.difference(_lastVoiceTime).inSeconds > 3) { // 稍微加長語音間隔，避免抬腳過程中頻繁打擾
      _lastVoiceTime = now;
      return text;
    }
    return null;
  }

  void _upgradeDifficulty() {
    successCount = 0;
    _hasTriggeredRaise = false;
    if (difficulty == RehabDifficulty.easy) {
      difficulty = RehabDifficulty.medium;
    } else if (difficulty == RehabDifficulty.medium) {
      difficulty = RehabDifficulty.hard;
    }
  }
}