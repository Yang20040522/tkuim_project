// lib/actions/reach_action.dart
//
// 伸手舉高訓練 — 判定邏輯。implements BodyRehabAction。

import 'dart:math' as math;
import '../models/body_frame.dart';
import 'body_rehab_action.dart';
import 'wipe_body_action.dart' show RehabDifficulty;

enum _ReachState { waitStart, reachingUp, holding, pullingDown }

class ReachAction implements BodyRehabAction {
  RehabDifficulty difficulty;
  int successCount = 0;
  final int targetCount = 3;

  _ReachState _currentState = _ReachState.waitStart;
  RehabJoint? _activeWrist;
  RehabJoint? _activeShoulder;

  DateTime _lastVoiceTime = DateTime.now();
  DateTime _holdStartTime = DateTime.now();
  DateTime _lastRepTime = DateTime.now();

  ReachAction({this.difficulty = RehabDifficulty.easy});

  // ── 合約要求 ──────────────────────────────────────────────
  @override
  String get title => '伸手舉高訓練';

  @override
  String get initialHint => '先舉一下手鎖定,再將手放下準備';

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
    final leftHip = frame.joints[RehabJoint.leftHip];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftWrist == null ||
        rightWrist == null ||
        leftHip == null) {
      return RehabFeedback.none;
    }

    // 1. 自動偵測活躍手
    if (_activeWrist == null) {
      if (leftWrist.dy < leftShoulder.dy) {
        _activeWrist = RehabJoint.leftWrist;
        _activeShoulder = RehabJoint.leftShoulder;
        return RehabFeedback(prompt: _speakThrottled('已鎖定左手,請先將手放下準備'));
      } else if (rightWrist.dy < rightShoulder.dy) {
        _activeWrist = RehabJoint.rightWrist;
        _activeShoulder = RehabJoint.rightShoulder;
        return RehabFeedback(prompt: _speakThrottled('已鎖定右手,請先將手放下準備'));
      }
      return RehabFeedback.none;
    }

    final shoulder = frame.joints[_activeShoulder!];
    final wrist = frame.joints[_activeWrist!];
    if (shoulder == null || wrist == null) return RehabFeedback.none;

    // 2. 防後仰借力
    final spineDx = leftShoulder.dx - leftHip.dx;
    final spineDy = leftShoulder.dy - leftHip.dy;
    final spineAngle = math.atan2(spineDx, spineDy) * (180 / math.pi);
    if (spineAngle < -20 || spineAngle > 20) {
      return RehabFeedback(prompt: _speakThrottled('身體請保持挺直,不要後仰借力'));
    }

    // 3. 難度參數
    final headEstimateY = shoulder.dy - 0.20;
    final targetHeightY = (difficulty == RehabDifficulty.easy)
        ? shoulder.dy - 0.10
        : (difficulty == RehabDifficulty.medium)
            ? headEstimateY
            : headEstimateY - 0.10;
    final restingHeightY = shoulder.dy + 0.20;

    // 4. 狀態機
    final now = DateTime.now();

    switch (_currentState) {
      case _ReachState.waitStart:
        if (wrist.dy > restingHeightY) {
          _currentState = _ReachState.reachingUp;
          return RehabFeedback(prompt: _speakThrottled('預備完成,請用力往上舉高'));
        }
        break;

      case _ReachState.reachingUp:
        if (wrist.dy < targetHeightY) {
          if (difficulty == RehabDifficulty.hard) {
            _currentState = _ReachState.holding;
            _holdStartTime = now;
            return RehabFeedback(prompt: _speakThrottled('撐住 3 秒!'));
          } else {
            _currentState = _ReachState.pullingDown;
            return RehabFeedback(prompt: _speakThrottled('很好,請慢慢放下'));
          }
        }
        break;

      case _ReachState.holding:
        if (wrist.dy > targetHeightY + 0.05) {
          _currentState = _ReachState.reachingUp;
          return RehabFeedback(prompt: _speakThrottled('手掉下來了,請再次舉高並撐住'));
        } else {
          if (now.difference(_holdStartTime).inSeconds >= 3) {
            _currentState = _ReachState.pullingDown;
            return RehabFeedback(prompt: _speakThrottled('非常穩定!請慢慢放下'));
          }
        }
        break;

      case _ReachState.pullingDown:
        if (wrist.dy > restingHeightY) {
          final durationMs = now.difference(_lastRepTime).inMilliseconds;

          if (durationMs > 1500) {
            successCount++;
            _lastRepTime = now;
            _currentState = _ReachState.reachingUp;

            if (successCount >= targetCount) {
              _upgradeDifficulty();
              return const RehabFeedback(
                prompt: '完美過關!解鎖下一個難度!',
                scored: true,
                leveledUp: true,
              );
            }
            return const RehabFeedback(
              prompt: '完成一次!請繼續往上舉',
              scored: true,
            );
          } else {
            _lastRepTime = now;
            _currentState = _ReachState.waitStart;
            return RehabFeedback(
                prompt: _speakThrottled('放下太快了!請用肌肉控制慢慢放下'));
          }
        }
        break;
    }

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
    _currentState = _ReachState.waitStart;
    _activeWrist = null;     // 升級時重新綁定手
    _activeShoulder = null;
    if (difficulty == RehabDifficulty.easy) {
      difficulty = RehabDifficulty.medium;
    } else if (difficulty == RehabDifficulty.medium) {
      difficulty = RehabDifficulty.hard;
    }
  }
}