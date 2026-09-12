import '../../actions/body_rehab_action.dart';

/// 被動觀察既有全身 Action 輸出的單次動作品質評分器。
///
/// 本類別不讀關節角度、不判斷動作是否成功，也不改變 Action 狀態；
/// [RehabFeedback.scored] 仍是唯一的完成一次依據。
class BodyTrainingScoreTracker {
  BodyTrainingScoreTracker({this.correctionPenalty = 8});

  final int correctionPenalty;

  final List<int> _repScores = <int>[];
  final List<String> _mistakeLogs = <String>[];
  String? _activeCorrection;
  int _currentRepCorrectionCount = 0;

  List<int> get repScores => List<int>.unmodifiable(_repScores);
  List<String> get mistakeLogs => List<String>.unmodifiable(_mistakeLogs);
  int? get currentRepScore => _repScores.isEmpty ? null : _repScores.last;

  double? get averageScore {
    if (_repScores.isEmpty) return null;
    return _repScores.reduce((left, right) => left + right) / _repScores.length;
  }

  /// 觀察一幀既有 Action 結果；只有 [feedback.scored] 才會產生分數。
  int? observe({
    required RehabFeedback feedback,
    required String? displayedPrompt,
    required bool skeletonValid,
    required bool trainingActive,
  }) {
    if (trainingActive && skeletonValid) {
      // 相機／骨架／選擇狀態只是暫時中斷，不可把原本仍存在的修正
      // 清掉後又重算一次。
      if (!_isUnavailablePrompt(displayedPrompt)) {
        final correction = _correctionFrom(displayedPrompt);
        if (correction == null) {
          _activeCorrection = null;
        } else if (correction != _activeCorrection) {
          _activeCorrection = correction;
          _currentRepCorrectionCount++;
          _mistakeLogs.add(
            '第 ${_repScores.length + 1} 次：${displayedPrompt!.trim()}',
          );
        }
      }
    }

    if (!feedback.scored) return null;

    final score =
        (100 - _currentRepCorrectionCount * correctionPenalty).clamp(0, 100);
    _repScores.add(score);
    _currentRepCorrectionCount = 0;
    _activeCorrection = null;
    return score;
  }

  /// 開始新難度或新場次時重置；暫停與切換鏡頭不可呼叫。
  void reset() {
    _repScores.clear();
    _mistakeLogs.clear();
    _currentRepCorrectionCount = 0;
    _activeCorrection = null;
  }

  String? _correctionFrom(String? prompt) {
    final text = prompt?.trim();
    if (text == null || text.isEmpty) return null;

    final normalized = text.replaceAll(RegExp(r'\s+'), '');

    if (_isUnavailablePrompt(text)) return null;

    // 資料／等待／選擇狀態不是姿勢錯誤。
    // 這裡以外的提示才可能清除或替換目前修正。
    const clearlyPositiveMarkers = <String>[
      '做得很好',
      '很好',
      '很棒',
      '太棒',
      '非常棒',
      '非常好',
      '完美',
    ];
    if (clearlyPositiveMarkers.any(normalized.contains)) return null;
    if (normalized.startsWith('預備') ||
        normalized.startsWith('開始') ||
        normalized.startsWith('站穩後')) {
      return null;
    }

    // 先辨識明確修正語意；這些是文字分類，不是 Action 的角度門檻。
    const correctionMarkers = <String>[
      '不要',
      '太早',
      '太快',
      '晃動',
      '側傾',
      '借力',
      '落後',
      '掉下來',
      '抬高',
      '站直',
      '坐直',
      '伸直',
      '畫大',
      '內夾',
      '腳跟',
      '踩穩',
      '彎曲',
      '再往',
      '再蹲',
      '再抬',
      '放鬆肩膀',
      '雙手要',
      '支撐腳',
      '重心',
      '保持小腿',
      '往後仰',
      '歪斜',
      '聳肩',
      '控制慢慢',
    ];
    if (correctionMarkers.any(normalized.contains)) return normalized;

    // 成功、進度與準備提示不扣分。
    const positiveMarkers = <String>[
      '做得很好',
      '很好',
      '很棒',
      '太棒',
      '非常棒',
      '非常好',
      '完美',
      '完成',
      '成功',
      '解鎖',
      '升級',
      '過關',
      '開始',
      '預備',
      '撐住',
      '慢慢放下',
      '慢慢收回',
      '站穩後',
    ];
    if (positiveMarkers.any(normalized.contains)) return null;

    return null;
  }

  bool _isUnavailablePrompt(String? prompt) {
    final normalized = prompt?.trim().replaceAll(RegExp(r'\s+'), '');
    if (normalized == null || normalized.isEmpty) return false;

    const unavailableMarkers = <String>[
      '鏡頭',
      '偵測',
      '資料不足',
      '請先選擇',
      '已選擇',
      '已鎖定',
      '等待',
      '倒數',
      '暫停',
      '載入',
      '連線',
    ];
    return unavailableMarkers.any(normalized.contains);
  }
}
