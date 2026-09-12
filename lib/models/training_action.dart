// lib/models/training_action.dart
//
// ✅ 新增：raiseBothArms, elbowForward, wristExtension, wristSideBend
// ✅ TrainingRecord 新增 videoPath 欄位(訓練錄影)
// ✅ DifficultyOption 新增 targetReps 欄位,每難度各自預設次數(初階多、進階少)
// 🩺 2026-08-20:側蹲、坐站標記為「建議恢復狀況較佳者練習」

enum ActionType {
  turnPalm,
  sidePinch,
  bodyTest,
  wipeBody,
  drawCircle,
  reach,
  raiseBothArms,
  elbowForward,
  wristExtension, // 檢查拼字是否為小寫 w 開頭的 wristExtension
  wristSideBend, // 檢查拼字是否為小寫 w 開頭的 wristSideBend
  sitToStand,
  lateralStep,
}

enum DifficultyLevel { level1, level2, level3 }

class TrainingAction {
  final ActionType type;
  final String name;
  final String emoji;
  final String description;
  final List<DifficultyOption> difficulties;

  const TrainingAction({
    required this.type,
    required this.name,
    required this.emoji,
    required this.description,
    required this.difficulties,
  });
}

class DifficultyOption {
  final DifficultyLevel level;
  final String label;
  final String description;
  final int targetReps;

  const DifficultyOption({
    required this.level,
    required this.label,
    required this.description,
    this.targetReps = 10,
  });

  DifficultyOption copyWithReps(int reps) => DifficultyOption(
        level: level,
        label: label,
        description: description,
        targetReps: reps,
      );
}

const List<TrainingAction> kTrainingActions = [
  TrainingAction(
    type: ActionType.turnPalm,
    name: '翻掌訓練',
    emoji: '🖐️',
    description: '訓練手腕旋轉與翻掌控制能力',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1,
          label: 'Level 1',
          description: '初階 — 容錯較高',
          targetReps: 10),
      DifficultyOption(
          level: DifficultyLevel.level2,
          label: 'Level 2',
          description: '中階 — 要求嚴格',
          targetReps: 8),
    ],
  ),
  TrainingAction(
    type: ActionType.sidePinch,
    name: '側捏訓練',
    emoji: '🤏',
    description: '訓練手指精細動作與捏握力',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1,
          label: 'Level 1',
          description: '初階 — 微幅側捏',
          targetReps: 10),
      DifficultyOption(
          level: DifficultyLevel.level2,
          label: 'Level 2',
          description: '中階 — 標準動作',
          targetReps: 8),
      DifficultyOption(
          level: DifficultyLevel.level3,
          label: 'Level 3',
          description: '進階 — 連擊模式',
          targetReps: 6),
    ],
  ),
  TrainingAction(
    type: ActionType.wipeBody,
    name: '站姿抬腳式訓練',
    emoji: '🦿',
    description: '站姿下左右抬膝，鍛鍊下肢平衡與核心穩定，腳掌盡量放平往上抬',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1,
          label: '初級',
          description: '抬膝幅度小 — 高容錯',
          targetReps: 10),
      DifficultyOption(
          level: DifficultyLevel.level2,
          label: '中級',
          description: '抬膝至腰部高度，嚴格檢測身體晃動',
          targetReps: 8),
      DifficultyOption(
          level: DifficultyLevel.level3,
          label: '高級',
          description: '抬膝過腰並定格 2 秒',
          targetReps: 6),
    ],
  ),
  TrainingAction(
    type: ActionType.drawCircle,
    name: '畫圓訓練',
    emoji: '⭕',
    description: '訓練肩關節活動度與手臂畫圓控制，上半圓大拇指朝上，下半圓自然下垂',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1,
          label: '初級',
          description: '小圓 — 高容錯',
          targetReps: 10),
      DifficultyOption(
          level: DifficultyLevel.level2,
          label: '中級',
          description: '標準圓',
          targetReps: 8),
      DifficultyOption(
          level: DifficultyLevel.level3,
          label: '高級',
          description: '大圓 — 要求手臂完全伸直',
          targetReps: 6),
    ],
  ),
  TrainingAction(
    type: ActionType.reach,
    name: '伸手舉高訓練',
    emoji: '🙋',
    description: '訓練肩關節上舉活動度與肌肉控制',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1,
          label: '初級',
          description: '舉過肩膀即可',
          targetReps: 10),
      DifficultyOption(
          level: DifficultyLevel.level2,
          label: '中級',
          description: '舉過頭頂',
          targetReps: 8),
      DifficultyOption(
          level: DifficultyLevel.level3,
          label: '高級',
          description: '舉過頭頂並定格 3 秒',
          targetReps: 6),
    ],
  ),
  TrainingAction(
    type: ActionType.bodyTest,
    name: '全身骨架偵測',
    emoji: '🦴',
    description: 'RTMPose 全身 133 關鍵點即時追蹤',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1,
          label: 'Beta',
          description: '測試模式',
          targetReps: 10),
    ],
  ),

  // ── 新增 4 個動作 ──────────────────────────────────────────

  TrainingAction(
    type: ActionType.raiseBothArms,
    name: '雙手抬舉式',
    emoji: '🙌',
    description: '雙手交扣往上抬舉,訓練肩膀活動度與核心穩定，舉到最高時大拇指朝上',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1,
          label: '初級',
          description: '抬到肩膀水平即可',
          targetReps: 10),
      DifficultyOption(
          level: DifficultyLevel.level2,
          label: '中級',
          description: '抬過頭頂並撐住 2 秒',
          targetReps: 8),
      DifficultyOption(
          level: DifficultyLevel.level3,
          label: '高級',
          description: '抬到最高位置撐住 3 秒',
          targetReps: 6),
    ],
  ),
  TrainingAction(
    type: ActionType.elbowForward,
    name: '手肘屈伸訓練',
    emoji: '🤲',
    description: '雙手交扣後手肘來回伸直收回,訓練手肘關節活動度',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1,
          label: '初級',
          description: '手肘伸到接近 130 度',
          targetReps: 10),
      DifficultyOption(
          level: DifficultyLevel.level2,
          label: '中級',
          description: '手肘伸直到 150 度並撐住 2 秒',
          targetReps: 8),
      DifficultyOption(
          level: DifficultyLevel.level3,
          label: '高級',
          description: '手肘完全伸直並撐住 3 秒',
          targetReps: 6),
    ],
  ),
  TrainingAction(
    type: ActionType.wristExtension,
    name: '翹手腕式',
    emoji: '🤚',
    description: '手腕背屈與掌屈來回訓練，從空手到拿水壺循序漸進',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1,
          label: 'Level 1',
          description: '空手 — 手腕上下彎曲',
          targetReps: 10),
      DifficultyOption(
          level: DifficultyLevel.level2,
          label: 'Level 2',
          description: '拿水壺 — 加重訓練，幅度要求更大',
          targetReps: 8),
    ],
  ),
  TrainingAction(
    type: ActionType.wristSideBend,
    name: '左右彎手腕式',
    emoji: '↔️',
    description: '手腕橈偏與尺偏來回訓練，改善手腕側向活動度',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1,
          label: '標準',
          description: '手腕左右來回彎曲，完成 10 次',
          targetReps: 10),
    ],
  ),
  TrainingAction(
    type: ActionType.sitToStand,
    name: '坐站訓練',
    emoji: '🪑',
    description: '訓練腿部力量與站起穩定度（建議恢復狀況較佳者練習）',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1,
          label: '初級',
          description: '微蹲即達標 — 膝蓋彎曲到 140 度',
          targetReps: 10),
      DifficultyOption(
          level: DifficultyLevel.level2,
          label: '中級',
          description: '半蹲 — 大腿接近平行地面',
          targetReps: 8),
      DifficultyOption(
          level: DifficultyLevel.level3,
          label: '高級',
          description: '半蹲撐住 3 秒',
          targetReps: 6),
    ],
  ),
  TrainingAction(
    type: ActionType.lateralStep,
    name: '側跨步訓練',
    emoji: '🚶',
    description: '訓練下肢平衡與單側肌力,防止跌倒（建議恢復狀況較佳者練習）',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1,
          label: '初級',
          description: '微跨即達標 — 膝蓋彎曲到 140 度',
          targetReps: 10),
      DifficultyOption(
          level: DifficultyLevel.level2,
          label: '中級',
          description: '半蹲側弓步',
          targetReps: 8),
      DifficultyOption(
          level: DifficultyLevel.level3,
          label: '高級',
          description: '深側弓步撐住 2 秒',
          targetReps: 6),
    ],
  ),
];

class TrainingRecord {
  final int? id;

  /// 同一次自動升級訓練共用同一個 sessionId。
  ///
  /// 自動升級：auto:xxxx
  /// 手動升級／單獨訓練：manual:xxxx
  ///
  /// 舊資料可能為 null。
  final String? sessionId;

  final String timestamp;
  final String actionName;
  final int difficulty;
  final int durationSeconds;
  final List<String> mistakeLogs;
  final String? videoPath;
  final String? videoUrl;
  final int completedReps;
  final int targetReps;
  final double? averageBodyScore;
  final List<int> bodyRepScores;
  final double? templateScore;
  final String? templateId;
  final String? templateName;
  final int templateValidRepCount;
  final List<double> templateRepScores;
  final List<String> templateDifferenceSummary;
  final bool isSynced;
  final bool isVideoSynced;

  TrainingRecord({
    this.id,
    this.sessionId,
    required this.timestamp,
    required this.actionName,
    required this.difficulty,
    required this.durationSeconds,
    required this.mistakeLogs,
    this.videoPath,
    this.videoUrl,
    this.completedReps = 0,
    this.targetReps = 10,
    this.averageBodyScore,
    this.bodyRepScores = const <int>[],
    this.templateScore,
    this.templateId,
    this.templateName,
    this.templateValidRepCount = 0,
    this.templateRepScores = const <double>[],
    this.templateDifferenceSummary = const <String>[],
    this.isSynced = false,
    bool? isVideoSynced,
  }) : isVideoSynced = isVideoSynced ?? videoPath == null;

  bool get hasVideo => videoPath != null || videoUrl != null;

  bool get isAutomaticLevelUpSession =>
      sessionId != null && sessionId!.startsWith('auto:');

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'timestamp': timestamp,
        'actionName': actionName,
        'difficulty': difficulty,
        'durationSeconds': durationSeconds,
        'mistakeLogs': mistakeLogs,
        'videoPath': videoPath,
        'videoUrl': videoUrl,
        'completedReps': completedReps,
        'targetReps': targetReps,
        'averageBodyScore': averageBodyScore,
        'bodyRepScores': bodyRepScores,
        'templateScore': templateScore,
        'templateId': templateId,
        'templateName': templateName,
        'templateValidRepCount': templateValidRepCount,
        'templateRepScores': templateRepScores,
        'templateDifferenceSummary': templateDifferenceSummary,
        'isSynced': isSynced,
        'isVideoSynced': isVideoSynced,
      };

  factory TrainingRecord.fromJson(Map<String, dynamic> json) {
    final videoPath = json['videoPath']?.toString();

    return TrainingRecord(
      id: (json['id'] as num?)?.toInt(),
      sessionId: json['sessionId']?.toString(),
      timestamp: json['timestamp']?.toString() ?? '',
      actionName: json['actionName']?.toString() ?? '',
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      mistakeLogs: List<String>.from(json['mistakeLogs'] ?? const []),
      videoPath: videoPath,
      videoUrl: json['videoUrl']?.toString(),
      completedReps: (json['completedReps'] as num?)?.toInt() ?? 0,
      targetReps: (json['targetReps'] as num?)?.toInt() ?? 10,
      averageBodyScore: (json['averageBodyScore'] as num?)?.toDouble() ??
          (json['bodyScore'] as num?)?.toDouble(),
      bodyRepScores: (json['bodyRepScores'] as List<dynamic>? ?? const [])
          .whereType<num>()
          .map((score) => score.round().clamp(0, 100).toInt())
          .toList(),
      templateScore: (json['templateScore'] as num?)?.toDouble(),
      templateId: json['templateId']?.toString(),
      templateName: json['templateName']?.toString(),
      templateValidRepCount:
          (json['templateValidRepCount'] as num?)?.toInt() ?? 0,
      templateRepScores:
          (json['templateRepScores'] as List<dynamic>? ?? const [])
              .whereType<num>()
              .map((score) => score.toDouble().clamp(0, 100).toDouble())
              .toList(),
      templateDifferenceSummary:
          List<String>.from(json['templateDifferenceSummary'] ?? const []),
      isSynced: json['isSynced'] as bool? ?? false,
      isVideoSynced: json.containsKey('isVideoSynced')
          ? json['isVideoSynced'] as bool? ?? false
          : videoPath == null,
    );
  }

  TrainingRecord copyWith({
    int? id,
    bool clearId = false,
    String? sessionId,
    bool replaceSessionId = false,
    String? videoPath,
    bool replaceVideoPath = false,
    String? videoUrl,
    bool replaceVideoUrl = false,
    int? completedReps,
    int? targetReps,
    double? averageBodyScore,
    List<int>? bodyRepScores,
    double? templateScore,
    String? templateId,
    String? templateName,
    int? templateValidRepCount,
    List<double>? templateRepScores,
    List<String>? templateDifferenceSummary,
    bool? isSynced,
    bool? isVideoSynced,
  }) =>
      TrainingRecord(
        id: clearId ? null : id ?? this.id,
        sessionId: replaceSessionId ? sessionId : sessionId ?? this.sessionId,
        timestamp: timestamp,
        actionName: actionName,
        difficulty: difficulty,
        durationSeconds: durationSeconds,
        mistakeLogs: List<String>.from(mistakeLogs),
        videoPath: replaceVideoPath ? videoPath : this.videoPath,
        videoUrl: replaceVideoUrl ? videoUrl : this.videoUrl,
        completedReps: completedReps ?? this.completedReps,
        targetReps: targetReps ?? this.targetReps,
        averageBodyScore: averageBodyScore ?? this.averageBodyScore,
        bodyRepScores: bodyRepScores ?? this.bodyRepScores,
        templateScore: templateScore ?? this.templateScore,
        templateId: templateId ?? this.templateId,
        templateName: templateName ?? this.templateName,
        templateValidRepCount:
            templateValidRepCount ?? this.templateValidRepCount,
        templateRepScores: templateRepScores ?? this.templateRepScores,
        templateDifferenceSummary:
            templateDifferenceSummary ?? this.templateDifferenceSummary,
        isSynced: isSynced ?? this.isSynced,
        isVideoSynced: isVideoSynced ?? this.isVideoSynced,
      );

  TrainingRecord copyWithVideoPath(String? path) => copyWith(
        videoPath: path,
        replaceVideoPath: true,
        isVideoSynced: path == null,
      );

  TrainingRecord copyWithSynced(
    bool synced, {
    int? historyId,
  }) =>
      copyWith(
        id: historyId,
        isSynced: synced,
      );

  TrainingRecord copyWithVideoSynced(
    bool synced, {
    String? remoteVideoUrl,
  }) =>
      copyWith(
        isVideoSynced: synced,
        videoUrl: remoteVideoUrl,
        replaceVideoUrl: remoteVideoUrl != null,
      );
}
