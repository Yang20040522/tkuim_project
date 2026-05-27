// lib/models/training_action.dart

enum ActionType { turnPalm, sidePinch, bodyTest, wipeBody, drawCircle, reach } // ✅ 新增 bodyTest

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

  // 在 kTrainingActions 列表的最下面，直接把 bodyTest 替換覆蓋成這樣：

  TrainingAction(
    type: ActionType.wipeBody,   // ← 從 bodyTest 改成 wipeBody
    name: '功能性擦拭訓練',
    emoji: '🧼',
    description: '融合日常擦澡動作,訓練核心穩定、防聳肩與手肘伸展控制',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1,
          label: '初級',
          description: '擦拭大腿 — 動作幅度小、高容錯'),
      DifficultyOption(
          level: DifficultyLevel.level2,
          label: '中級',
          description: '中階 — 擦拭腹部,嚴格檢測聳肩代償'),
      DifficultyOption(
          level: DifficultyLevel.level3,
          label: '高級',
          description: '進階 — 全身擦拭,挑戰手肘完全伸直'),
    ],
  ),

  TrainingAction(
    type: ActionType.drawCircle,
    name: '畫圓訓練',
    emoji: '⭕',
    description: '訓練肩關節活動度與手臂畫圓控制',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1, label: '初級',
          description: '小圓 — 高容錯'),
      DifficultyOption(
          level: DifficultyLevel.level2, label: '中級',
          description: '標準圓'),
      DifficultyOption(
          level: DifficultyLevel.level3, label: '高級',
          description: '大圓 — 要求手臂完全伸直'),
    ],
  ),

  TrainingAction(
    type: ActionType.reach,
    name: '伸手舉高訓練',
    emoji: '🙋',
    description: '訓練肩關節上舉活動度與肌肉控制',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1, label: '初級',
          description: '舉過肩膀即可'),
      DifficultyOption(
          level: DifficultyLevel.level2, label: '中級',
          description: '舉過頭頂'),
      DifficultyOption(
          level: DifficultyLevel.level3, label: '高級',
          description: '舉過頭頂並定格 3 秒'),
    ],
  ),

  // ✅ 新增：全身骨架測試（不需要難度選項，用假的佔位）
  TrainingAction(
    type: ActionType.bodyTest,
    name: '全身骨架偵測',
    emoji: '🦴',
    description: 'RTMPose 全身 133 關鍵點即時追蹤',
    difficulties: [
      DifficultyOption(
          level: DifficultyLevel.level1,
          label: 'Beta',
          description: '測試模式'),
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