// lib/actions/standing_knee_raise_action.dart
//
// 站姿抬腳式訓練 — 判定邏輯。
// implements BodyRehabAction, 可直接丟進 body_training_screen。
//
// ✅ 修正重點：原本只判定左腳（leftHip/leftKnee/leftAnkle），
//    如果患側是右腳會永遠判定不到目標區。
//    比照 ReachAction 的做法，加入 selectLeftLeg() / selectRightLeg()，
//    讓外部（UI 按鈕）可以選擇要訓練哪一腳。
//
// 🩺 2026-08-20 治療師回饋:
//   抬腳時腳掌應盡量放平往上抬，不要往下垂。
//   新增 leftBigToe/rightBigToe、leftHeel/rightHeel 座標時才會啟用此檢查
//   (資料源尚未接上前直接跳過，不影響原本判定)。
//
// 🩺 2026-08-21 治療師回饋:
//   聳肩容忍度、身體後仰容忍度原本中/高階相同或固定值,沒有明顯分級。
//   改成三階分級:初階最寬鬆,高階最嚴格。
//
// 🩺 2026-09-06 治療師回饋(簡單版/困難版):
//   建議提供兩種練習模式:
//     - 簡單版：患側腳負責抬起(動),好腳負責撐。
//     - 困難版：反過來,患側腳負責撐(單腳承重),好腳負責抬起(動)。
//       這個模式除了原本的抬腳判定,還多一道「支撐腳(患側)有沒有晃動」
//       的平衡偵測 —— 困難版真正考驗的是患側單腳站穩的能力,不只是
//       抬腳角度而已。
//   API 改成:selectTrainedLeg(isLeft:) 選患側是左/右腳(標記用),
//   selectSupportLeg(isLeft:) 直接選哪隻腳當支撐腳(另一隻腳自動變成
//   要動的那隻腳)。簡單版/困難版是「支撐腳是不是選到患側」算出來的
//   結果,不是另外選的選項 —— 這樣使用者只需要做「選患側、選支撐腳」
//   兩個直接的動作,不用理解額外的模式概念。
//
// 🩺 2026-09-06 治療師回饋(2)—— 支撐腳站直 + 定格計時:
//   1. 原本只檢查支撐腳「有沒有跟著抬起」跟「有沒有左右晃動」,沒有
//      檢查支撐腳膝蓋角度——如果支撐腳一直微彎(腿軟/代償)完全抓不到。
//      這次加上支撐腳角度檢查,不分簡單/困難版都要查(誰在撐,誰就要
//      站直),角度門檻依難度分級(150°/160°/165°)。
//   2. 原本「動」的那隻腳只要瞬間進入目標區間就直接計分,跟文案寫的
//      「高階要定格 2 秒」對不起來。這次加上跟手肘屈伸/雙手抬舉一樣
//      的定格計時(holding)邏輯:初/中階維持原本行為(進入即算),
//      高階要撐滿 2 秒才計分,提早放下會提示「太早放下」但不扣分,
//      算是慢下來重練一次。
//
// 🆕 2026-09-06 治療師回饋(3)—— 補上 LegRoleSelectable 介面:
//   讓 body_training_screen 能用統一的「選患側 → 選簡單/困難版」
//   兩步驟選腳畫面來驅動這個動作,不用另外寫一套 UI 邏輯。
//   selectSimpleMode()/selectHardMode() 內部直接換算成
//   selectSupportLeg() 呼叫,語意更直接,UI 不用自己算左右腳。

import 'dart:math' as math;
import '../models/body_frame.dart';
import 'body_rehab_action.dart';

class StandingKneeRaiseAction
    implements BodyRehabAction, LevelUpControllable, LegRoleSelectable {
  RehabDifficulty difficulty;
  int successCount = 0;
  int targetCount;

  bool _hasTriggeredRaise = false;
  DateTime _lastVoiceTime = DateTime.now();

  // 🆕 是否正等待使用者決定要不要升級(達標後、確認前為 true)
  bool _pendingLevelUp = false;

  // ── 患側腳 + 支撐腳選擇 ──────────────────────────────────
  bool? _trainedLegIsLeft; // 患側是左腳(true)還是右腳(false),null = 未選(給提示文字/紀錄用)
  bool? _supportLegIsLeft; // 🆕 支撐腳是左腳(true)還是右腳(false),null = 未選(直接決定判定用哪隻腳)

  // 實際「動(抬起)」的那隻腳的關節(= 支撐腳選定後,自動變成另一隻腳)
  RehabJoint? _movingHip;
  RehabJoint? _movingKnee;
  RehabJoint? _movingAnkle;
  RehabJoint? _movingBigToe;
  RehabJoint? _movingHeel;

  // 實際「撐」的那隻腳的關節
  RehabJoint? _supportHip;
  RehabJoint? _supportKnee;
  RehabJoint? _supportAnkle; // 🆕 用來算支撐腳的膝蓋角度,檢查有沒有站直

  // 🆕 困難版:支撐腳(患側)水平位置的最近幾幀歷史,用來判斷有沒有晃動
  final List<double> _supportHipXHistory = [];
  static const int _supportHistoryFrames = 12;

  // 🆕 抬腳「定格」狀態:進入目標區間後,依難度要求撐住一段時間才計分,
  //    而不是瞬間碰到就算(對應 training_action.dart 高階「定格 2 秒」的描述)
  bool _isHolding = false;
  DateTime _holdStartTime = DateTime.now();

  StandingKneeRaiseAction({
    this.difficulty = RehabDifficulty.easy,
    this.targetCount = 3,
  });

  // ── 供 UI 呼叫：選患側腳(標記用) + 直接選支撐腳(決定判定) ──────────
  bool get legAndModeSelected => _trainedLegIsLeft != null && _supportLegIsLeft != null;

  @override
  bool get trainedLegSelected => _trainedLegIsLeft != null; // 🆕

  /// 選患側是左腳還是右腳(單純標記,決定提示文字要講「患側」還是「好腳」)
  @override
  void selectTrainedLeg({required bool isLeft}) {
    _trainedLegIsLeft = isLeft;
  }

  /// 🆕 直接選哪隻腳當支撐腳,另一隻腳自動變成「動(抬起)」的那隻腳。
  ///    支撐腳選的剛好是患側 → 困難版；選的是好腳 → 簡單版。
  void selectSupportLeg({required bool isLeft}) {
    _supportLegIsLeft = isLeft;
    _applyLegMapping();
  }

  /// 🆕 簡單版:患側動、好腳撐 —— 支撐腳自動選「非患側」那隻
  @override
  void selectSimpleMode() {
    if (_trainedLegIsLeft == null) return;
    selectSupportLeg(isLeft: !_trainedLegIsLeft!);
  }

  /// 🆕 困難版:患側撐、好腳動 —— 支撐腳自動選「患側」那隻
  @override
  void selectHardMode() {
    if (_trainedLegIsLeft == null) return;
    selectSupportLeg(isLeft: _trainedLegIsLeft!);
  }

  // ⚠️ 向下相容用:等同「選這隻腳當患側,且患側負責動(簡單版)」，
  //    也就是支撐腳自動選對面那隻。建議 UI 改用 selectTrainedLeg()/
  //    selectSupportLeg() 讓使用者能直接選困難版(支撐腳=患側)。
  void selectLeftLeg() {
    selectTrainedLeg(isLeft: true);
    selectSupportLeg(isLeft: false);
  }

  void selectRightLeg() {
    selectTrainedLeg(isLeft: false);
    selectSupportLeg(isLeft: true);
  }

  /// 目前是簡單版(患側動)還是困難版(患側撐),算出來的,不是直接選的
  @override
  TrainingLegRole get role {
    if (_trainedLegIsLeft == null || _supportLegIsLeft == null) {
      return TrainingLegRole.moveTrainedLeg;
    }
    return _supportLegIsLeft == _trainedLegIsLeft
        ? TrainingLegRole.supportOnTrainedLeg
        : TrainingLegRole.moveTrainedLeg;
  }

  void _applyLegMapping() {
    if (_supportLegIsLeft == null) return;
    final supportIsLeft = _supportLegIsLeft!;

    if (supportIsLeft) {
      _supportHip = RehabJoint.leftHip;
      _supportKnee = RehabJoint.leftKnee;
      _supportAnkle = RehabJoint.leftAnkle; // 🆕
      _movingHip = RehabJoint.rightHip;
      _movingKnee = RehabJoint.rightKnee;
      _movingAnkle = RehabJoint.rightAnkle;
      _movingBigToe = RehabJoint.rightBigToe;
      _movingHeel = RehabJoint.rightHeel;
    } else {
      _supportHip = RehabJoint.rightHip;
      _supportKnee = RehabJoint.rightKnee;
      _supportAnkle = RehabJoint.rightAnkle; // 🆕
      _movingHip = RehabJoint.leftHip;
      _movingKnee = RehabJoint.leftKnee;
      _movingAnkle = RehabJoint.leftAnkle;
      _movingBigToe = RehabJoint.leftBigToe;
      _movingHeel = RehabJoint.leftHeel;
    }

    // 換腳後重置狀態,避免拿舊的判定結果誤判
    _hasTriggeredRaise = false;
    _isHolding = false; // 🆕
    _supportHipXHistory.clear();
  }

  // ── 合約要求 ──────────────────────────────────────────────
  @override
  String get title => '站姿抬腳式訓練';

  /// 簡單版/困難版的顯示文字,給 UI 顯示用(算出來的,不是選的)
  @override
  String get roleLabel => role == TrainingLegRole.moveTrainedLeg
      ? '簡單版(患側動,好腳撐)'
      : '困難版(患側撐,好腳動)';

  @override
  String get initialHint => legAndModeSelected
      ? (role == TrainingLegRole.moveTrainedLeg
          ? '雙腳與肩同寬站立，手扶椅背或拐杖，準備抬起患側腳，腳掌盡量放平'
          : '雙腳與肩同寬站立，手扶椅背或拐杖，這次換好腳抬起，患側腳負責站穩支撐')
      : '請先選擇患側是左腳／右腳,再選擇要用哪隻腳支撐';

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

  // 🩺 依難度分級的防代償容錯值(聳肩、後仰),初階最寬鬆,高階最嚴格
  double get _shoulderTolerance => switch (difficulty) {
        RehabDifficulty.easy => 0.10,
        RehabDifficulty.medium => 0.06,
        RehabDifficulty.hard => 0.04,
      };

  double get _spineToleranceDeg => switch (difficulty) {
        RehabDifficulty.easy => 20.0,
        RehabDifficulty.medium => 15.0,
        RehabDifficulty.hard => 10.0,
      };

  // 🆕 困難版:支撐腳(患側)容許的水平晃動範圍(正規化座標)。
  //    這是估計值,實際測試時可能需要調整。
  static const double _supportSwayTolerance = 0.045;

  // 🆕 支撐腳最低要打直到幾度才算「站直」,初階寬鬆,高階嚴格
  double get _supportStraightMinAngle => switch (difficulty) {
        RehabDifficulty.easy => 150.0,
        RehabDifficulty.medium => 160.0,
        RehabDifficulty.hard => 165.0,
      };

  // 🆕 抬腳要「定格」幾秒才計分:對應 training_action.dart 裡的文案
  //    (初/中級沒特別要求撐住,高級寫「定格 2 秒」)
  int get _requiredHoldSeconds => switch (difficulty) {
        RehabDifficulty.easy => 0,
        RehabDifficulty.medium => 0,
        RehabDifficulty.hard => 2,
      };

  // ── 合約核心: 每幀判定 ────────────────────────────────────
  @override
  RehabFeedback update(BodyFrame frame) {
    if (_pendingLevelUp) return RehabFeedback.none;
    // 尚未選好患側腳 + 模式 → 等待 UI 按鈕，不做任何偵測
    if (!legAndModeSelected) return RehabFeedback.none;

    // 取得上半身骨架（防代償用，雙肩仍需雙側資料）
    final leftShoulder = frame.joints[RehabJoint.leftShoulder];
    final rightShoulder = frame.joints[RehabJoint.rightShoulder];

    // 取得「動」的那隻腳的骨架（動作判定用）
    final hip = frame.joints[_movingHip!];
    final knee = frame.joints[_movingKnee!];
    final ankle = frame.joints[_movingAnkle!];

    if (leftShoulder == null ||
        rightShoulder == null ||
        hip == null ||
        knee == null ||
        ankle == null) {
      return RehabFeedback.none;
    }

    // 1. 防代償：防過度傾斜/聳肩 (保持兩側肩膀水平)
    final shoulderDrop = (leftShoulder.dy - rightShoulder.dy).abs();
    if (shoulderDrop > _shoulderTolerance) {
      return RehabFeedback(prompt: _speakThrottled('請保持身體直立，不要歪斜或聳肩喔'));
    }

    // 2. 防代償：防身體後仰（用「動」那隻腳那側的肩膀-髖部）
    final activeShoulder =
        _movingHip == RehabJoint.leftHip ? leftShoulder : rightShoulder;
    final spineDx = activeShoulder.dx - hip.dx;
    final spineDy = activeShoulder.dy - hip.dy;
    final spineAngle = math.atan2(spineDx, spineDy) * (180 / math.pi);
    if (spineAngle < -_spineToleranceDeg) {
      return RehabFeedback(prompt: _speakThrottled('站直一點，身體不要往後仰'));
    }

    // 🆕 2.5 支撐腳檢查:不管簡單版或困難版,正在撐的那隻腳都要站直、
    //    不能跟著抬起。困難版(支撐腳=患側)另外多一道晃動偵測,
    //    因為困難版真正在考驗患側單腳承重的穩定度。
    {
      final supportHip = frame.joints[_supportHip!];
      final supportKnee = frame.joints[_supportKnee!];
      final supportAnkle = frame.joints[_supportAnkle!];
      if (supportHip != null && supportKnee != null && supportAnkle != null) {
        // 支撐腳不能跟著抬起(膝蓋不能比髖部高)
        if (supportKnee.dy < supportHip.dy) {
          return RehabFeedback(
              prompt: _speakThrottled('支撐腳請確實踩穩地面，不要跟著抬起'));
        }

        // 🆕 支撐腳膝蓋角度檢查:必須站直,不能一直微彎(腿軟/代償)
        final supportKneeAngle =
            _calculateAngle(supportHip, supportKnee, supportAnkle);
        if (supportKneeAngle < _supportStraightMinAngle) {
          return RehabFeedback(prompt: _speakThrottled(
              role == TrainingLegRole.supportOnTrainedLeg
                  ? '支撐腳(患側)膝蓋請打直,不要彎曲'
                  : '支撐腳膝蓋請打直,站穩再抬腳'));
        }

        // 困難版才需要細看支撐腳(患側)有沒有左右晃動(平衡挑戰)
        if (role == TrainingLegRole.supportOnTrainedLeg) {
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
                  prompt: _speakThrottled('支撐腳(患側)晃動太大，請站穩後再繼續'));
            }
          }
        } else {
          _supportHipXHistory.clear();
        }
      }
    }

    // 3. 計算關節角度
    // 髖關節角度（大腿與軀幹的夾角）：利用肩膀、髖部、膝蓋計算
    final hipAngle = _calculateAngle(activeShoulder, hip, knee);
    // 膝關節彎曲角度：利用髖部、膝蓋、腳踝計算
    final kneeAngle = _calculateAngle(hip, knee, ankle);

    // 4. 目標區與難度判定
    bool isInTargetZone = false;

    switch (difficulty) {
      case RehabDifficulty.easy:
        // 初級：大腿微抬，膝蓋高於腳踝，髖關節彎曲角度（小於 140 度即可）
        isInTargetZone = knee.dy < hip.dy && hipAngle < 140.0;
        break;
      case RehabDifficulty.medium:
        // 中級（影片標準）：大腿抬平接近 90 度（hipAngle 約 90-110 度），且膝蓋自然彎曲（kneeAngle 約 80-110 度）
        isInTargetZone = knee.dy < hip.dy &&
            hipAngle <= 110.0 &&
            kneeAngle >= 80.0 && kneeAngle <= 110.0;
        break;
      case RehabDifficulty.hard:
        // 高級：大腿抬得更高（hipAngle < 90 度），且膝蓋能精準控制在約 90 度，停留更穩定
        isInTargetZone = knee.dy < hip.dy &&
            hipAngle < 90.0 &&
            kneeAngle >= 85.0 && kneeAngle <= 100.0;
        break;
    }

    // 🩺 4.5 腳掌平舉檢查:只在已抬起(knee.dy < hip.dy，代表大腿已離地)時檢查，
    //    腳趾明顯低於腳跟太多 = 腳掌下垂。資料源沒接上就跳過。
    if (knee.dy < hip.dy) {
      final bigToe = frame.joints[_movingBigToe!];
      final heel = frame.joints[_movingHeel!];
      if (bigToe != null && heel != null) {
        const droopMargin = 0.03; // 正規化座標容許誤差
        final isDrooping = bigToe.dy > heel.dy + droopMargin;
        if (isDrooping) {
          final prompt = _speakThrottled('腳掌盡量放平，腳尖不要往下垂');
          if (prompt != null) return RehabFeedback(prompt: prompt);
        }
      }
    }

    // 5. 計分與跳關邏輯(🆕 加入「定格」計時,不是碰到目標區就瞬間計分)
    if (isInTargetZone) {
      if (!_hasTriggeredRaise) {
        final holdSeconds = _requiredHoldSeconds;

        if (holdSeconds <= 0) {
          // 這個難度不需要定格,進入目標區就算完成(沿用原本行為)
          _hasTriggeredRaise = true;
          successCount++;
        } else {
          if (!_isHolding) {
            _isHolding = true;
            _holdStartTime = DateTime.now();
            return RehabFeedback(prompt: _speakThrottled('很好,慢慢抬,撐住 $holdSeconds 秒'));
          }
          final heldMs = DateTime.now().difference(_holdStartTime).inMilliseconds;
          if (heldMs < holdSeconds * 1000) {
            // 還在定格倒數中,不重複給提示,等時間到或掉出目標區
            return RehabFeedback.none;
          }
          _isHolding = false;
          _hasTriggeredRaise = true;
          successCount++;
        }

        if (successCount >= targetCount) {
          _pendingLevelUp = true;
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
    } else {
      // 🆕 撐不到規定秒數就掉出目標區 = 這次不計分,但也不算失敗扣分,提醒重來一次
      if (_isHolding && !_hasTriggeredRaise) {
        _isHolding = false;
        return RehabFeedback(prompt: _speakThrottled('太早放下了,請再抬高並撐住'));
      }
      if (knee.dy > hip.dy + 0.1) {
        // 當膝蓋放低，回到接近原起始站姿時，重置觸發開關，允許下一次計分
        _hasTriggeredRaise = false;
      }
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
    _isHolding = false; // 🆕
    _supportHipXHistory.clear();
    if (difficulty == RehabDifficulty.easy) {
      difficulty = RehabDifficulty.medium;
    } else if (difficulty == RehabDifficulty.medium) {
      difficulty = RehabDifficulty.hard;
    }
  }

  @override
  bool get isPendingLevelUp => _pendingLevelUp; // 🆕

  @override
  void confirmLevelUp({int? customTargetReps}) { // 🆕
    _pendingLevelUp = false;
    _upgradeDifficulty();
    if (customTargetReps != null && customTargetReps > 0) {
      targetCount = customTargetReps;
    }
  }

  @override
  void declineLevelUp() { // 🆕
    _pendingLevelUp = false;
    successCount = 0;
    _hasTriggeredRaise = false;
    _isHolding = false; // 🆕
    _supportHipXHistory.clear();
  }
}