// lib/models/training_action.dart
//
// ✅ 新增：raiseBothArms, elbowForward, wristExtension, wristSideBend

enum ActionType {
  turnPalm,
  sidePinch,
  bodyTest,
  wipeBody,
  drawCircle,
  reach,
  raiseBothArms,   
  elbowForward,    
  wristExtension,  // 檢查拼字是否為小寫 w 開頭的 wristExtension
  wristSideBend,   // 檢查拼字是否為小寫 w 開頭的 wristSideBend
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

  const DifficultyOption({
    required this.level,
    required this.label,
    required this.description,
  });
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
          description: '初階 — 容錯較高'),
      DifficultyOption(
          level: DifficultyLevel.level2,
          label: 'Level 2',
          description: '中階 — 要求嚴格'),
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
          description: '初階 — 微幅側捏'),
      DifficultyOption(
          level: DifficultyLevel.level2,
          label: 'Level 2',
          description: '中階 — 標準動作'),
      DifficultyOption(
          level: DifficultyLevel.level3,
          label: 'Level 3',
          description: '進階 — 連擊模式'),
    ],
  ),
  TrainingAction(
    type: ActionType.wipeBody,
    name: '功能性擦拭訓練',
    emoji: '🧼',
    description: '融合日常擦澡動作，訓練核心穩定、防聳肩與手肘伸展控制',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1,
          label: '初級',
          description: '擦拭大腿 — 動作幅度小、高容錯'),
      DifficultyOption(
          level: DifficultyLevel.level2,
          label: '中級',
          description: '擦拭腹部，嚴格檢測聳肩代償'),
      DifficultyOption(
          level: DifficultyLevel.level3,
          label: '高級',
          description: '全身擦拭，挑戰手肘完全伸直'),
    ],
  ),
  TrainingAction(
    type: ActionType.drawCircle,
    name: '畫圓訓練',
    emoji: '⭕',
    description: '訓練肩關節活動度與手臂畫圓控制',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1, label: '初級', description: '小圓 — 高容錯'),
      DifficultyOption(
          level: DifficultyLevel.level2, label: '中級', description: '標準圓'),
      DifficultyOption(
          level: DifficultyLevel.level3, label: '高級', description: '大圓 — 要求手臂完全伸直'),
    ],
  ),
  TrainingAction(
    type: ActionType.reach,
    name: '伸手舉高訓練',
    emoji: '🙋',
    description: '訓練肩關節上舉活動度與肌肉控制',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1, label: '初級', description: '舉過肩膀即可'),
      DifficultyOption(
          level: DifficultyLevel.level2, label: '中級', description: '舉過頭頂'),
      DifficultyOption(
          level: DifficultyLevel.level3, label: '高級', description: '舉過頭頂並定格 3 秒'),
    ],
  ),
  TrainingAction(
    type: ActionType.bodyTest,
    name: '全身骨架偵測',
    emoji: '🦴',
    description: 'RTMPose 全身 133 關鍵點即時追蹤',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1, label: 'Beta', description: '測試模式'),
    ],
  ),

  // ── 新增 4 個動作 ──────────────────────────────────────────

  TrainingAction(
    type: ActionType.raiseBothArms,
    name: '雙手抬舉式',
    emoji: '🙌',
    description: '雙手交扣往上抬舉過肩，訓練肩膀活動度與核心穩定',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1,
          label: '標準',
          description: '雙手交扣，抬舉過肩並撐住 2 秒'),
    ],
  ),
  TrainingAction(
    type: ActionType.elbowForward,
    name: '交扣手肘前伸式',
    emoji: '🤲',
    description: '雙手十指交扣向前推出伸直，訓練手肘伸展與肩膀前推',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1,
          label: '標準',
          description: '雙手交扣前推，撐住 2 秒再收回'),
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
          description: '空手 — 手腕上下彎曲'),
      DifficultyOption(
          level: DifficultyLevel.level2,
          label: 'Level 2',
          description: '拿水壺 — 加重訓練，幅度要求更大'),
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
          description: '手腕左右來回彎曲，完成 10 次'),
    ],
  ),
  TrainingAction(                        // ← 從這裡開始貼
    type: ActionType.sitToStand,
    name: '坐站訓練',
    emoji: '🦵',
    description: '訓練腿部力量與站起穩定度',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1,
          label: '初級',
          description: '微蹲 — 膝蓋彎曲到 140 度'),
      DifficultyOption(
          level: DifficultyLevel.level2,
          label: '中級',
          description: '半蹲 — 大腿接近平行地面'),
      DifficultyOption(
          level: DifficultyLevel.level3,
          label: '高級',
          description: '半蹲撐住 3 秒'),
    ],
  ),
  TrainingAction(
    type: ActionType.lateralStep,
    name: '側跨步訓練',
    emoji: '🚶',
    description: '訓練下肢平衡與單側肌力,防止跌倒',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1,
          label: '初級',
          description: '微跨 — 膝蓋彎曲到 140 度'),
      DifficultyOption(
          level: DifficultyLevel.level2,
          label: '中級',
          description: '半蹲側弓步'),
      DifficultyOption(
          level: DifficultyLevel.level3,
          label: '高級',
          description: '深側弓步撐住 2 秒'),
    ],
  ),
];

class TrainingRecord {
  final String timestamp;
  final String actionName;
  final int difficulty;
  final int durationSeconds;
  final List<String> mistakeLogs;

  TrainingRecord({
    required this.timestamp,
    required this.actionName,
    required this.difficulty,
    required this.durationSeconds,
    required this.mistakeLogs,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'actionName': actionName,
        'difficulty': difficulty,
        'durationSeconds': durationSeconds,
        'mistakeLogs': mistakeLogs,
      };

  factory TrainingRecord.fromJson(Map<String, dynamic> json) => TrainingRecord(
        timestamp: json['timestamp'] ?? '',
        actionName: json['actionName'] ?? '',
        difficulty: json['difficulty'] ?? 1,
        durationSeconds: json['durationSeconds'] ?? 0,
        mistakeLogs: List<String>.from(json['mistakeLogs'] ?? []),
      );
}