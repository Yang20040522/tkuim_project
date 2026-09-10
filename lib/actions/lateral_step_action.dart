// lib/actions/lateral_step_action.dart
//
// 側跨步訓練(LateralStep)
//
// 2026-09-09 修正版
//
// 判定原則：
// ✅ 只要指定腳「往側邊踏出去」再「收回來」就算完成一次。
// ✅ 不再要求跨步腳膝蓋一定要彎曲。
// ✅ 不再用 movingKneeAngle 當作開始或完成跨步的條件。
// ✅ 使用雙腳「水平 X 距離」判斷側跨，避免前後晃動被誤判。
// ✅ 距離門檻依髖寬自動縮放，降低人離鏡頭遠近造成的不穩定。
// ✅ 困難版仍保留患側支撐腳的晃動檢查。
// ✅ 高級仍保留跨出去後停 2 秒的要求。
// ✅ 保留原本患側/簡單版/困難版、自動升級等介面。

import 'dart:math' as math;

import '../models/body_frame.dart';
import 'body_rehab_action.dart';

enum _StepState {
  waiting,
  steppingOut,
  holding,
  returning,
}

class LateralStepAction
    implements BodyRehabAction, LevelUpControllable, LegRoleSelectable {
  RehabDifficulty difficulty;

  int _successCount = 0;
  int _targetCount = 8;

  _StepState _state = _StepState.waiting;

  DateTime _lastSpeakTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _holdStartTime = DateTime.now();

  bool _pendingLevelUp = false;

  // ─────────────────────────────────────────────
  // 患側 / 支撐腳選擇
  // ─────────────────────────────────────────────

  bool? _trainedLegIsLeft;
  bool? _supportLegIsLeft;

  RehabJoint? _movingHip;
  RehabJoint? _movingKnee;
  RehabJoint? _movingAnkle;

  RehabJoint? _supportHip;
  RehabJoint? _supportKnee;
  RehabJoint? _supportAnkle;

  // ─────────────────────────────────────────────
  // 起始站姿基準
  // ─────────────────────────────────────────────

  double? _baselineHorizontalFootDistance;

  // 連續幀確認，避免單幀抖動直接觸發。
  int _outStableFrames = 0;
  int _returnStableFrames = 0;

  static const int _requiredStableFrames = 3;

  // ─────────────────────────────────────────────
  // 困難版：支撐腳晃動
  // ─────────────────────────────────────────────

  final List<double> _supportHipXHistory = [];

  static const int _supportHistoryFrames = 12;
  static const double _supportSwayTolerance = 0.055;

  LateralStepAction({
    this.difficulty = RehabDifficulty.easy,
    int targetCount = 8,
  }) : _targetCount = targetCount;

  // ─────────────────────────────────────────────
  // UI 選擇介面
  // ─────────────────────────────────────────────

  @override
  bool get trainedLegSelected => _trainedLegIsLeft != null;

  @override
  bool get legAndModeSelected =>
      _trainedLegIsLeft != null && _supportLegIsLeft != null;

  @override
  void selectTrainedLeg({required bool isLeft}) {
    _trainedLegIsLeft = isLeft;
    _resetMotionState();
  }

  void selectSupportLeg({required bool isLeft}) {
    _supportLegIsLeft = isLeft;
    _applyLegMapping();
  }

  @override
  void selectSimpleMode() {
    if (_trainedLegIsLeft == null) return;

    // 簡單版：
    // 患側跨出去，好腳負責支撐。
    selectSupportLeg(
      isLeft: !_trainedLegIsLeft!,
    );
  }

  @override
  void selectHardMode() {
    if (_trainedLegIsLeft == null) return;

    // 困難版：
    // 患側負責支撐，好腳跨出去。
    selectSupportLeg(
      isLeft: _trainedLegIsLeft!,
    );
  }

  void _applyLegMapping() {
    if (_supportLegIsLeft == null) return;

    if (_supportLegIsLeft!) {
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

    _resetMotionState();
  }

  void _resetMotionState() {
    _state = _StepState.waiting;

    _baselineHorizontalFootDistance = null;

    _outStableFrames = 0;
    _returnStableFrames = 0;

    _supportHipXHistory.clear();
  }

  @override
  TrainingLegRole get role {
    if (_trainedLegIsLeft == null || _supportLegIsLeft == null) {
      return TrainingLegRole.moveTrainedLeg;
    }

    return _supportLegIsLeft == _trainedLegIsLeft
        ? TrainingLegRole.supportOnTrainedLeg
        : TrainingLegRole.moveTrainedLeg;
  }

  @override
  String get roleLabel {
    if (role == TrainingLegRole.moveTrainedLeg) {
      return '簡單版(患側跨步,好腳撐)';
    }

    return '困難版(患側撐,好腳跨步)';
  }

  // ─────────────────────────────────────────────
  // BodyRehabAction
  // ─────────────────────────────────────────────

  @override
  String get title => '側跨步訓練';

  @override
  String get initialHint {
    if (!legAndModeSelected) {
      return '請先選擇患側是左腳／右腳,再選擇簡單版或困難版';
    }

    if (role == TrainingLegRole.moveTrainedLeg) {
      return '雙腳站穩,將患側腳往側邊踏出去,再慢慢收回來';
    }

    return '患側腳站穩支撐,將好腳往側邊踏出去,再慢慢收回來';
  }

  @override
  String get difficultyLabel => switch (difficulty) {
        RehabDifficulty.easy => '初級',
        RehabDifficulty.medium => '中級',
        RehabDifficulty.hard => '高級',
      };

  // ─────────────────────────────────────────────
  // 跨步距離門檻
  //
  // 這裡刻意放寬。
  // 只要看得到明顯側跨，就可以判定。
  // ─────────────────────────────────────────────

  double get _stepDistanceRatio => switch (difficulty) {
        RehabDifficulty.easy => 0.22,
        RehabDifficulty.medium => 0.32,
        RehabDifficulty.hard => 0.42,
      };

  // 高級才要求停住。
  int get _holdSeconds => switch (difficulty) {
        RehabDifficulty.easy => 0,
        RehabDifficulty.medium => 0,
        RehabDifficulty.hard => 2,
      };

  @override
  RehabFeedback update(BodyFrame frame) {
    if (_pendingLevelUp) {
      return RehabFeedback.none;
    }

    if (!legAndModeSelected) {
      return RehabFeedback.none;
    }

    final movingHip = frame.joints[_movingHip!];
    final movingKnee = frame.joints[_movingKnee!];
    final movingAnkle = frame.joints[_movingAnkle!];

    final supportHip = frame.joints[_supportHip!];
    final supportKnee = frame.joints[_supportKnee!];
    final supportAnkle = frame.joints[_supportAnkle!];

    // knee 仍取出來只是確認骨架有完整抓到腿，
    // 不再拿 kneeAngle 當跨步成功條件。
    if (movingHip == null ||
        movingKnee == null ||
        movingAnkle == null ||
        supportHip == null ||
        supportKnee == null ||
        supportAnkle == null) {
      return RehabFeedback(
        prompt: _throttled(
          '請讓雙腿的髖部、膝蓋和腳踝都完整進入鏡頭',
        ),
      );
    }

    // ─────────────────────────────────────────────
    // 只看「左右水平方向」距離
    //
    // 側跨步的重點就是 X 軸距離拉開。
    // 不把 dy 算進去，避免腳往前後移也被算成側跨。
    // ─────────────────────────────────────────────

    final currentHorizontalFootDistance =
        (movingAnkle.dx - supportAnkle.dx).abs();

    final hipWidth = (movingHip.dx - supportHip.dx).abs();

    // 防止髖寬太小導致門檻異常。
    final safeHipWidth = math.max(hipWidth, 0.08);

    // ─────────────────────────────────────────────
    // 建立起始站姿基準
    // ─────────────────────────────────────────────

    if (_baselineHorizontalFootDistance == null) {
      _baselineHorizontalFootDistance = currentHorizontalFootDistance;

      return RehabFeedback(
        prompt: _throttled(
          '站穩後,把指定的腳往側邊踏出去',
        ),
      );
    }

    final baseline = _baselineHorizontalFootDistance!;

    final stepDelta = math.max(
      0.0,
      currentHorizontalFootDistance - baseline,
    );

    // 正式跨出去門檻。
    //
    // 至少 0.025 正規化距離，
    // 或髖寬的指定比例，取較大值。
    final requiredStepDelta = math.max(
      0.025,
      safeHipWidth * _stepDistanceRatio,
    );

    // 開始跨步門檻再小一點。
    final triggerStepDelta = math.max(
      0.015,
      requiredStepDelta * 0.55,
    );

    // 收回判定。
    final returnTolerance = math.max(
      0.018,
      requiredStepDelta * 0.35,
    );

    // ─────────────────────────────────────────────
    // 困難版：患側支撐腳晃動
    // ─────────────────────────────────────────────

    if (role == TrainingLegRole.supportOnTrainedLeg &&
        _state != _StepState.waiting) {
      _supportHipXHistory.add(
        supportHip.dx,
      );

      if (_supportHipXHistory.length > _supportHistoryFrames) {
        _supportHipXHistory.removeAt(0);
      }

      if (_supportHipXHistory.length >= 6) {
        final minX = _supportHipXHistory.reduce(math.min);

        final maxX = _supportHipXHistory.reduce(math.max);

        final sway = maxX - minX;

        if (sway > _supportSwayTolerance) {
          return RehabFeedback(
            prompt: _throttled(
              '支撐腳晃動比較大,請站穩再繼續',
            ),
          );
        }
      }
    } else {
      _supportHipXHistory.clear();
    }

    final now = DateTime.now();

    switch (_state) {
      // ───────────────────────────────────────────
      // 等待開始
      // ───────────────────────────────────────────
      case _StepState.waiting:
        if (stepDelta >= triggerStepDelta) {
          _outStableFrames++;
        } else {
          _outStableFrames = 0;

          // 人還沒開始跨時，
          // 緩慢更新站姿基準，吸收骨架小抖動。
          if ((currentHorizontalFootDistance - baseline).abs() < 0.015) {
            _baselineHorizontalFootDistance =
                baseline * 0.92 + currentHorizontalFootDistance * 0.08;
          }
        }

        if (_outStableFrames >= _requiredStableFrames) {
          _outStableFrames = 0;
          _state = _StepState.steppingOut;

          return RehabFeedback(
            prompt: _throttled(
              '很好,繼續往側邊踏出去',
            ),
          );
        }

        break;

      // ───────────────────────────────────────────
      // 正在跨出去
      // ───────────────────────────────────────────
      case _StepState.steppingOut:
        if (stepDelta >= requiredStepDelta) {
          _outStableFrames++;
        } else {
          _outStableFrames = 0;
        }

        if (_outStableFrames >= _requiredStableFrames) {
          _outStableFrames = 0;

          if (_holdSeconds > 0) {
            _state = _StepState.holding;

            _holdStartTime = now;

            return RehabFeedback(
              prompt: _throttled(
                '很好,停在這裡撐住 $_holdSeconds 秒',
              ),
            );
          }

          _state = _StepState.returning;

          return RehabFeedback(
            prompt: _throttled(
              '跨步完成,慢慢把腳收回原位',
            ),
          );
        }

        // 剛開始跨就又收回。
        if (stepDelta <= returnTolerance) {
          _state = _StepState.waiting;

          _outStableFrames = 0;

          return RehabFeedback(
            prompt: _throttled(
              '再往側邊踏遠一點',
            ),
          );
        }

        break;

      // ───────────────────────────────────────────
      // 高級停留
      // ───────────────────────────────────────────
      case _StepState.holding:
        // 如果腳收太多，重新跨。
        if (stepDelta < requiredStepDelta * 0.75) {
          _state = _StepState.steppingOut;

          return RehabFeedback(
            prompt: _throttled(
              '腳收回太早了,再往側邊踏出去',
            ),
          );
        }

        if (now
                .difference(
                  _holdStartTime,
                )
                .inSeconds >=
            _holdSeconds) {
          _state = _StepState.returning;

          return RehabFeedback(
            prompt: _throttled(
              '很好,現在慢慢把腳收回',
            ),
          );
        }

        break;

      // ───────────────────────────────────────────
      // 收回原位
      // ───────────────────────────────────────────
      case _StepState.returning:
        if (stepDelta <= returnTolerance) {
          _returnStableFrames++;
        } else {
          _returnStableFrames = 0;
        }

        if (_returnStableFrames >= _requiredStableFrames) {
          _returnStableFrames = 0;

          _successCount++;

          _state = _StepState.waiting;

          // 重新建立下一次的基準。
          _baselineHorizontalFootDistance = currentHorizontalFootDistance;

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

    return RehabFeedback.none;
  }

  // ─────────────────────────────────────────────
  // 語音節流
  // ─────────────────────────────────────────────

  String? _throttled(String text) {
    final now = DateTime.now();

    if (now
            .difference(
              _lastSpeakTime,
            )
            .inMilliseconds >
        2200) {
      _lastSpeakTime = now;
      return text;
    }

    return null;
  }

  // ─────────────────────────────────────────────
  // 難度升級
  // ─────────────────────────────────────────────

  bool _upgrade() {
    _successCount = 0;

    _resetMotionState();

    if (difficulty == RehabDifficulty.easy) {
      difficulty = RehabDifficulty.medium;

      return true;
    }

    if (difficulty == RehabDifficulty.medium) {
      difficulty = RehabDifficulty.hard;

      return true;
    }

    return false;
  }

  @override
  bool get isPendingLevelUp => _pendingLevelUp;

  @override
  void confirmLevelUp({
    int? customTargetReps,
  }) {
    _pendingLevelUp = false;

    _upgrade();

    if (customTargetReps != null && customTargetReps > 0) {
      _targetCount = customTargetReps;
    }
  }

  @override
  void declineLevelUp() {
    _pendingLevelUp = false;

    _successCount = 0;

    _resetMotionState();
  }
}
