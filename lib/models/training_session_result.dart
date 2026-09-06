import 'assignable_exercise.dart';

enum TrainingCompletionStatus {
  completed('COMPLETED');

  const TrainingCompletionStatus(this.apiValue);
  final String apiValue;

  static TrainingCompletionStatus fromJson(Object? value) => switch (value) {
        'COMPLETED' => TrainingCompletionStatus.completed,
        _ => throw FormatException('不支援的訓練完成狀態：$value'),
      };
}

class TrainingSessionResult {
  const TrainingSessionResult({
    required this.sessionId,
    required this.exerciseType,
    required this.exerciseId,
    required this.exerciseName,
    required this.completedSets,
    required this.completedReps,
    required this.targetSets,
    required this.targetReps,
    required this.startedAt,
    required this.completedAt,
    required this.durationSeconds,
    required this.status,
    required this.score,
  });

  final String sessionId;
  final AssignableExerciseType exerciseType;
  final String exerciseId;
  final String exerciseName;
  final int completedSets;
  final int completedReps;
  final int targetSets;
  final int targetReps;
  final DateTime startedAt;
  final DateTime completedAt;
  final int durationSeconds;
  final TrainingCompletionStatus status;
  final double score;

  Map<String, dynamic> toRequestJson() => {
        'sessionId': sessionId,
        'exerciseType': exerciseType.apiValue,
        'exerciseId': exerciseId,
        'completedSets': completedSets,
        'completedReps': completedReps,
        'targetSets': targetSets,
        'targetReps': targetReps,
        'durationSeconds': durationSeconds,
        'completionStatus': status.apiValue,
      };

  factory TrainingSessionResult.fromJson(Map<String, dynamic> json) {
    int integer(String key) {
      final value = json[key];
      if (value is num) return value.toInt();
      throw FormatException('$key 格式錯誤');
    }

    double number(String key) {
      final value = json[key];
      if (value is num && value.toDouble().isFinite) return value.toDouble();
      throw FormatException('$key 格式錯誤');
    }

    return TrainingSessionResult(
      sessionId: json['sessionId'] as String,
      exerciseType: AssignableExerciseType.fromJson(json['exerciseType']),
      exerciseId: json['exerciseId'].toString(),
      exerciseName: json['exerciseName'] as String,
      completedSets: integer('completedSets'),
      completedReps: integer('completedReps'),
      targetSets: integer('targetSets'),
      targetReps: integer('targetReps'),
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: DateTime.parse(json['completedAt'] as String),
      durationSeconds: integer('durationSeconds'),
      status: TrainingCompletionStatus.fromJson(json['completionStatus']),
      score: number('score').clamp(0.0, 100.0),
    );
  }
}
