// lib/actions/lateral_step_action.dart
//
// 側跨步訓練(LateralStep) — 下肢平衡 + 單側肌力
//
// 三個難度(膝彎深度):
//   easy   ≤ 140°(微跨)
//   medium ≤ 110°(半蹲側弓步)
//   hard   ≤ 90° + 撐住 2 秒(深側弓步)
//
// 重點防代償:留在原地的腳要伸直,不能跟著彎
//
// 🩺 2026-08-21 治療師回饋:
//   支撐腳(留在原地那隻)容錯值原本不分難度,一律 145°。
//   改成三階分級:初階更寬鬆(容許支撐腳稍微彎),高階更嚴格(要求完全打直)。
//
// 🩺 2026-09-06 治療師回饋(重大改動):
//   1. 側跨步的難度深度(140°/110°/90°)之前是照抄坐站訓練的數字,
//      治療師說側跨步要「修小一點」，範圍不該跟蹲站共用同一組角度。
//      這次先把三階角度都調小、動作幅度縮小,實際數字仍需治療師實測校正。
//   2. 原本完全靠「自動偵測哪隻腳先彎」來判斷跨步腳,沒辦法讓使用者
//      指定要練哪一腳。改成跟站姿抬腳式一致的直接選腳 API：
//        selectTrainedLeg(isLeft:)  → 選患側是左腳/右腳(標記用,決定
//                                      提示文字要講「患側」還是「好腳」)
//        selectSupportLeg(isLeft:)  → 直接選哪隻腳當支撐腳,另一隻腳
//                                      自動變成跨步(動)的那隻腳
//      支撐腳選的剛好是患側 → 困難版；選的是好腳 → 簡單版，這是算出來
//      的結果,不是另外選的選項。兩個都選了才開始偵測，不再自動猜。
//   3. 困難版多了「支撐腳(患側)有沒有晃動」的平衡偵測 —— 跟站姿抬腳式
//      困難版一樣，這是額外的、簡單版沒有的判定邏輯。
//
// 🆕 2026-09-06 治療師回饋(2)—— 補上 LegRoleSelectable 介面:
//   讓 body_training_screen 能用統一的「選患側 → 選簡單/困難版」
//   兩步驟選腳畫面來驅動這個動作,寫法跟 standing_knee_raise_action
//   完全一致。

import 'dart:math' as math;
import 'package:flutter/painting.dart';
import '../models/body_frame.dart';
import 'body_rehab_action.dart';

enum _StepState { standing, steppingOut, holding, returning }

class LateralStepAction
    implements BodyRehabAction, LevelUpControllable, LegRoleSelectable {
  RehabDifficulty difficulty;
  int _successCount = 0;
  int _targetCount = 8;

  _StepState _state = _StepState.standing;
  DateTime _lastSpeakTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _holdStartTime = DateTime.now();
  bool _pendingLevelUp = false;

  // ── 患側腳 + 支撐腳選擇(取代原本的自動偵測) ─────────────────────
  bool? _trainedLegIsLeft; // 患側是左腳(true)還是右腳(false),null = 未選(標記用)
  bool? _supportLegIsLeft; // 🆕 支撐腳是左腳(true)還是右腳(false),null = 未選(直接決定判定)

  RehabJoint? _movingHip;
  RehabJoint? _movingKnee;
  RehabJoint? _movingAnkle;

  RehabJoint? _supportHip;
  RehabJoint? _supportKnee;
  RehabJoint? _supportAnkle;

  // 🆕 困難版:支撐腳(患側)水平位置的最近幾幀歷史,用來判斷有沒有晃動
  final List<double> _supportHipXHistory = [];
  static const int _supportHistoryFrames = 12;
  static const double _supportSwayTolerance = 0.05;

  LateralStepAction({
    this.difficulty = RehabDifficulty.easy,
    int targetCount = 8,
  }) : _targetCount = targetCount;

  // ── 供 UI 呼叫：選患側腳(標記用) + 直接選支撐腳(決定判定) ──────────
  bool get legAndModeSelected => _trainedLegIsLeft != null && _supportLegIsLeft != null;

  @override
  bool get trainedLegSelected => _trainedLegIsLeft != null; // 🆕

  /// 選患側是左腳還是右腳(單純標記,決定提示文字要講「患側」還是「好腳」)
  @override
  void selectTrainedLeg({required bool isLeft}) {
    _trainedLegIsLeft = isLeft;
  }

  /// 🆕 直接選哪隻腳當支撐腳,另一隻腳自動變成「跨步(動)」的那隻腳。
  ///    支撐腳選的剛好是患側 → 困難版；選的是好腳 → 簡單版。
  void selectSupportLeg({required bool isLeft}) {
    _supportLegIsLeft = isLeft;
    _applyLegMapping();
  }

  /// 🆕 簡單版:患側跨步、好腳撐 —— 支撐腳自動選「非患側」那隻
  @override
  void selectSimpleMode() {
    if (_trainedLegIsLeft == null) return;
    selectSupportLeg(isLeft: !_trainedLegIsLeft!);
  }

  /// 🆕 困難版:患側撐、好腳跨步 —— 支撐腳自動選「患側」那隻
  @override
  void selectHardMode() {
    if (_trainedLegIsLeft == null) return;
    selectSupportLeg(isLeft: _trainedLegIsLeft!);
  }

  void _applyLegMapping() {
    if (_supportLegIsLeft == null) return;
    final supportIsLeft = _supportLegIsLeft!;

    if (supportIsLeft) {
      _supportHip = RehabJoint.leftHip;
      _supportKnee = RehabJoint.leftKnee;
      _supportAnkle = RehabJoint.leftAnkle;
      _movingHip = RehabJoint.rightHip;
      _movingKnee = RehabJoint.rightKnee;
      _movingAnkle = RehabJoint.rightAnkle;
    } else {
      _supportHip = RehabJoint.rightHip;
      _supportKnee = RehabJoint.rightKnee;
      _supportAnkle = RehabJoint.rightAnkle;
      _movingHip = RehabJoint.leftHip;
      _movingKnee = RehabJoint.leftKnee;
      _movingAnkle = RehabJoint.leftAnkle;
    }

    // 換腳後重置狀態,避免拿舊的判定結果誤判
    _state = _StepState.standing;
    _supportHipXHistory.clear();
  }

  /// 目前是簡單版(患側跨步)還是困難版(患側撐),算出來的,不是直接選的
  @override
  TrainingLegRole get role {
    if (_trainedLegIsLeft == null || _supportLegIsLeft == null) {
      return TrainingLegRole.moveTrainedLeg;
    }
    return _supportLegIsLeft == _trainedLegIsLeft
        ? TrainingLegRole.supportOnTrainedLeg
        : TrainingLegRole.moveTrainedLeg;
  }

  /// 簡單版/困難版的顯示文字,給 UI 顯示用
  @override
  String get roleLabel => role == TrainingLegRole.moveTrainedLeg
      ? '簡單版(患側跨步,好腳撐)'
      : '困難版(患側撐,好腳跨步)';

  // ── BodyRehabAction 合約 ────────────────────────────

  @override
  String get title => '側跨步訓練';

  @override
  String get initialHint => legAndModeSelected
      ? (role == TrainingLegRole.moveTrainedLeg
          ? '請扶穩支撐物,雙腳與肩同寬站立,準備用患側腳跨步'
          : '請扶穩支撐物,雙腳與肩同寬站立,這次換好腳跨步,患側腳負責站穩支撐')
      : '請先選擇患側是左腳／右腳,再選擇要用哪隻腳支撐';

  @override
  String get difficultyLabel => switch (difficulty) {
        RehabDifficulty.easy => '初級',
        RehabDifficulty.medium => '中級',
        RehabDifficulty.hard => '高級',
      };

  // 🩺 支撐腳(留在原地那隻)防代償容忍度:初階寬鬆,高階嚴格
  double get _inactiveLegTolerance => switch (difficulty) {
        RehabDifficulty.easy => 138.0,
        RehabDifficulty.medium => 145.0,
        RehabDifficulty.hard => 152.0,
      };

  // 🩺 2026-09-06:範圍修小,不再跟坐站訓練共用同一組角度。
  //    這組數字是先縮小的估計值,實際門檻仍需治療師實測校正。
  double get _targetBendAngle => switch (difficulty) {
        RehabDifficulty.easy => 155.0,   // 原本 140.0,幅度縮小
        RehabDifficulty.medium => 135.0, // 原本 110.0
        RehabDifficulty.hard => 118.0,   // 原本 90.0
      };

  @override
  RehabFeedback update(BodyFrame frame) {
    if (_pendingLevelUp) return const RehabFeedback();
    // 尚未選好患側腳 + 模式 → 等待 UI 按鈕，不做任何偵測
    if (!legAndModeSelected) return const RehabFeedback();

    final movingHip = frame.joints[_movingHip!];
    final movingKnee = frame.joints[_movingKnee!];
    final movingAnkle = frame.joints[_movingAnkle!];
    final supportHip = frame.joints[_supportHip!];
    final supportKnee = frame.joints[_supportKnee!];
    final supportAnkle = frame.joints[_supportAnkle!];

    if (movingHip == null || movingKnee == null || movingAnkle == null ||
        supportHip == null || supportKnee == null || supportAnkle == null) {
      return const RehabFeedback();
    }

    final movingKneeAngle = _angle(movingHip, movingKnee, movingAnkle);
    final supportKneeAngle = _angle(supportHip, supportKnee, supportAnkle);

    const standingThreshold = 160.0;
    final targetBendAngle = _targetBendAngle;

    final now = DateTime.now();

    // 🆕 困難版:支撐腳(患側)平衡偵測 —— 全程都要檢查,不只 steppingOut 才查
    if (role == TrainingLegRole.supportOnTrainedLeg &&
        _state != _StepState.standing) {
      _supportHipXHistory.add(supportHip.dx);
      if (_supportHipXHistory.length > _supportHistoryFrames) {
        _supportHipXHistory.removeAt(0);
      }
      if (_supportHipXHistory.length >= 6) {
        final minX = _supportHipXHistory.reduce(math.min);
        final maxX = _supportHipXHistory.reduce(math.max);
        final sway = maxX - minX;
        if (sway > _supportSwayTolerance) {
          return RehabFeedback(
              prompt: _throttled('支撐腳(患側)晃動太大,請站穩後再繼續'));
        }
      }
    } else {
      _supportHipXHistory.clear();
    }

    switch (_state) {
      case _StepState.standing:
        // 等待「動」的那隻腳開始彎曲(不再自動偵測是哪一腳,已經固定好了)
        if (movingKneeAngle < 150.0 && supportKneeAngle > standingThreshold) {
          _state = _StepState.steppingOut;
          return RehabFeedback(
              prompt: _throttled(role == TrainingLegRole.moveTrainedLeg
                  ? '患側腳跨出,重心慢慢轉移'
                  : '好腳跨出,患側腳請站穩'));
        }
        // 提醒:如果反而是支撐腳先彎了,代表用錯腳跨步
        if (supportKneeAngle < 150.0 && movingKneeAngle > standingThreshold) {
          return RehabFeedback(
              prompt: _throttled('請用指定的那隻腳跨步,另一隻腳負責站穩支撐'));
        }
        break;

      case _StepState.steppingOut:
        // 防代償:留在原地(支撐)的腳不能彎(容忍度依難度分級)
        if (supportKneeAngle < _inactiveLegTolerance) {
          return RehabFeedback(
              prompt: _throttled('支撐腳請保持伸直,不要跟著彎'));
        }

        if (movingKneeAngle <= targetBendAngle) {
          if (difficulty == RehabDifficulty.hard) {
            _state = _StepState.holding;
            _holdStartTime = now;
            return RehabFeedback(prompt: _throttled('很好,停在這個深度撐住兩秒'));
          } else {
            _state = _StepState.returning;
            return RehabFeedback(prompt: _throttled('深度足夠,請用力推回站姿'));
          }
        }
        break;

      case _StepState.holding:
        if (movingKneeAngle > targetBendAngle + 15.0) {
          _state = _StepState.steppingOut;
          return RehabFeedback(prompt: _throttled('太早站起來了,請再蹲深一點'));
        }
        if (now.difference(_holdStartTime).inSeconds >= 2) {
          _state = _StepState.returning;
          return RehabFeedback(prompt: _throttled('完美,現在請用力推回站立'));
        }
        break;

      case _StepState.returning:
        // 兩腳都回站直 = 完成一次
        if (movingKneeAngle >= standingThreshold &&
            supportKneeAngle >= standingThreshold) {
          _successCount++;
          _state = _StepState.standing;

          if (_successCount >= _targetCount) {
            _pendingLevelUp = true;
            return const RehabFeedback(
              scored: true,
              leveledUp: true,
              prompt: '下肢控制很棒!',
            );
          }
          return const RehabFeedback(
            scored: true,
            prompt: '完成一次,請繼續跨步',
          );
        }
        break;
    }

    return const RehabFeedback();
  }

  // ── 私有 ────────────────────────────────────────────

  double _angle(Offset p1, Offset p2, Offset p3) {
    final a = math.sqrt(math.pow(p2.dx - p3.dx, 2) + math.pow(p2.dy - p3.dy, 2));
    final b = math.sqrt(math.pow(p1.dx - p3.dx, 2) + math.pow(p1.dy - p3.dy, 2));
    final c = math.sqrt(math.pow(p1.dx - p2.dx, 2) + math.pow(p1.dy - p2.dy, 2));
    if (a * c == 0) return 0.0;
    final cosB = (math.pow(a, 2) + math.pow(c, 2) - math.pow(b, 2)) / (2 * a * c);
    return math.acos(cosB.clamp(-1.0, 1.0)) * (180 / math.pi);
  }

  String? _throttled(String text) {
    final now = DateTime.now();
    if (now.difference(_lastSpeakTime).inMilliseconds > 2500) {
      _lastSpeakTime = now;
      return text;
    }
    return null;
  }

  bool _upgrade() {
    _successCount = 0;
    _state = _StepState.standing;
    _supportHipXHistory.clear();
    if (difficulty == RehabDifficulty.easy) {
      difficulty = RehabDifficulty.medium;
      return true;
    } else if (difficulty == RehabDifficulty.medium) {
      difficulty = RehabDifficulty.hard;
      return true;
    }
    return false;
  }

  @override
  bool get isPendingLevelUp => _pendingLevelUp; // 🆕

  @override
  void confirmLevelUp({int? customTargetReps}) { // 🆕
    _pendingLevelUp = false;
    _upgrade();
    if (customTargetReps != null && customTargetReps > 0) {
      _targetCount = customTargetReps;
    }
  }

  @override
  void declineLevelUp() { // 🆕
    _pendingLevelUp = false;
    _successCount = 0;
    _state = _StepState.standing;
    _supportHipXHistory.clear();
  }
}