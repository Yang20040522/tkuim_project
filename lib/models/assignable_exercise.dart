enum AssignableExerciseType {
  defaultExercise('DEFAULT'),
  custom('CUSTOM');

  final String apiValue;

  const AssignableExerciseType(this.apiValue);

  static AssignableExerciseType fromJson(Object? value) {
    return switch (value?.toString().toUpperCase()) {
      'DEFAULT' => AssignableExerciseType.defaultExercise,
      'CUSTOM' => AssignableExerciseType.custom,
      _ => throw FormatException('不支援的復健動作類型：$value'),
    };
  }
}

class AssignableExercise {
  final String id;
  final String name;
  final String description;
  final AssignableExerciseType type;
  final bool assigned;

  const AssignableExercise({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.assigned,
  });

  String get identityKey => '${type.apiValue}:$id';

  AssignableExercise copyWith({bool? assigned}) {
    return AssignableExercise(
      id: id,
      name: name,
      description: description,
      type: type,
      assigned: assigned ?? this.assigned,
    );
  }

  factory AssignableExercise.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final name = json['name']?.toString();
    if (id == null || id.isEmpty || name == null || name.isEmpty) {
      throw const FormatException('復健動作缺少 id 或 name');
    }
    return AssignableExercise(
      id: id,
      name: name,
      description: json['description']?.toString() ?? '',
      type: AssignableExerciseType.fromJson(json['type']),
      assigned: json['assigned'] == true,
    );
  }
}
