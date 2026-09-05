import 'evaluation_rule.dart';
import 'exercise_keyframe.dart';
import '../features/pose_measurement/evaluation/pose_measurement_rule.dart';

class CustomRehabExercise {
  final String id;
  final String name;
  final String description;
  final String? createdByTherapistId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int repetitions;
  final int sets;
  final double holdSeconds;
  final double restSeconds;
  final double duration;
  final List<ExerciseKeyframe> keyframes;
  final List<EvaluationRule> evaluationRules;
  final List<PoseMeasurementRule> poseMeasurementRules;

  CustomRehabExercise({
    required this.id,
    required this.name,
    required this.description,
    this.createdByTherapistId,
    required this.createdAt,
    required this.updatedAt,
    required this.repetitions,
    required this.sets,
    required this.holdSeconds,
    required this.restSeconds,
    required this.duration,
    required List<ExerciseKeyframe> keyframes,
    required List<EvaluationRule> evaluationRules,
    List<PoseMeasurementRule> poseMeasurementRules = const [],
  })  : assert(repetitions > 0),
        assert(sets > 0),
        assert(holdSeconds >= 0 && holdSeconds.isFinite),
        assert(restSeconds >= 0 && restSeconds.isFinite),
        assert(duration >= 0 && duration.isFinite),
        keyframes = List.unmodifiable(_orderedKeyframes(keyframes, duration)),
        evaluationRules = List.unmodifiable(evaluationRules),
        poseMeasurementRules = List.unmodifiable(poseMeasurementRules);

  static List<ExerciseKeyframe> _orderedKeyframes(
    List<ExerciseKeyframe> source,
    double duration,
  ) {
    final result = List<ExerciseKeyframe>.of(source)
      ..sort((a, b) {
        final timeComparison = a.time.compareTo(b.time);
        return timeComparison != 0 ? timeComparison : a.id.compareTo(b.id);
      });
    if (result.any((keyframe) => keyframe.time > duration)) {
      throw ArgumentError('Keyframe time 不可超過動作 duration');
    }
    for (var i = 1; i < result.length; i++) {
      if (result[i - 1].time == result[i].time) {
        throw ArgumentError('Keyframe time 不可重複: ${result[i].time}');
      }
    }
    return result;
  }

  CustomRehabExercise copyWith({
    String? id,
    String? name,
    String? description,
    String? createdByTherapistId,
    bool clearCreatedByTherapistId = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? repetitions,
    int? sets,
    double? holdSeconds,
    double? restSeconds,
    double? duration,
    List<ExerciseKeyframe>? keyframes,
    List<EvaluationRule>? evaluationRules,
    List<PoseMeasurementRule>? poseMeasurementRules,
  }) {
    return CustomRehabExercise(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdByTherapistId: clearCreatedByTherapistId
          ? null
          : createdByTherapistId ?? this.createdByTherapistId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      repetitions: repetitions ?? this.repetitions,
      sets: sets ?? this.sets,
      holdSeconds: holdSeconds ?? this.holdSeconds,
      restSeconds: restSeconds ?? this.restSeconds,
      duration: duration ?? this.duration,
      keyframes: keyframes ?? this.keyframes,
      evaluationRules: evaluationRules ?? this.evaluationRules,
      poseMeasurementRules: poseMeasurementRules ?? this.poseMeasurementRules,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'createdByTherapistId': createdByTherapistId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'repetitions': repetitions,
        'sets': sets,
        'holdSeconds': holdSeconds,
        'restSeconds': restSeconds,
        'duration': duration,
        'keyframes': keyframes.map((item) => item.toJson()).toList(),
        'evaluationRules':
            evaluationRules.map((item) => item.toJson()).toList(),
        'poseMeasurementRules':
            poseMeasurementRules.map((item) => item.toJson()).toList(),
      };

  factory CustomRehabExercise.fromJson(Map<String, dynamic> json) {
    final repetitions = json['repetitions'];
    final sets = json['sets'];
    final hold = _finiteDouble(json['holdSeconds'], field: 'holdSeconds');
    final rest = _finiteDouble(json['restSeconds'], field: 'restSeconds');
    final duration = _finiteDouble(json['duration'], field: 'duration');
    if (repetitions is! int || repetitions <= 0 || sets is! int || sets <= 0) {
      throw const FormatException('repetitions 與 sets 必須大於 0');
    }
    if (hold < 0 || rest < 0 || duration < 0) {
      throw const FormatException('時間設定不可為負數');
    }
    final rawKeyframes = json['keyframes'];
    final rawRules = json['evaluationRules'];
    final rawPoseRules = json['poseMeasurementRules'];
    if (rawKeyframes is! List || rawRules is! List) {
      throw const FormatException('keyframes 或 evaluationRules 格式錯誤');
    }
    try {
      return CustomRehabExercise(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        createdByTherapistId: json['createdByTherapistId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        repetitions: repetitions,
        sets: sets,
        holdSeconds: hold,
        restSeconds: rest,
        duration: duration,
        keyframes: rawKeyframes
            .map((item) => ExerciseKeyframe.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList(),
        evaluationRules: rawRules
            .map((item) =>
                EvaluationRule.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        poseMeasurementRules: _parsePoseMeasurementRules(rawPoseRules),
      );
    } on TypeError catch (error) {
      throw FormatException('CustomRehabExercise 欄位格式錯誤', error);
    } on ArgumentError catch (error) {
      throw FormatException(error.message.toString(), error);
    }
  }

  static List<PoseMeasurementRule> _parsePoseMeasurementRules(Object? value) {
    if (value == null) return const [];
    if (value is! List) return const [];
    final result = <PoseMeasurementRule>[];
    final measurements = <Object>{};
    for (final item in value) {
      final rule = PoseMeasurementRule.tryFromJson(item);
      if (rule != null && measurements.add(rule.measurement)) {
        result.add(rule);
      }
    }
    return result;
  }

  static double _finiteDouble(dynamic value, {required String field}) {
    final number = value is num ? value.toDouble() : null;
    if (number == null || !number.isFinite) {
      throw FormatException('$field 必須是有限數值');
    }
    return number;
  }
}
