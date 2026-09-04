class AssignablePatient {
  final String patientId;
  final String patientName;

  const AssignablePatient({
    required this.patientId,
    required this.patientName,
  });

  factory AssignablePatient.fromJson(Map<String, dynamic> json) {
    final patientId = json['patientId'];
    final patientName = json['patientName'];
    if (patientId == null || patientName is! String) {
      throw const FormatException('患者資料格式錯誤');
    }
    return AssignablePatient(
      patientId: patientId.toString(),
      patientName: patientName,
    );
  }
}

class CustomExerciseAssignment {
  final String assignmentId;
  final String exerciseId;
  final String exerciseName;
  final String exerciseDescription;
  final String therapistId;
  final String therapistName;
  final String patientId;
  final String patientName;
  final DateTime assignedAt;

  const CustomExerciseAssignment({
    required this.assignmentId,
    required this.exerciseId,
    required this.exerciseName,
    required this.exerciseDescription,
    required this.therapistId,
    required this.therapistName,
    required this.patientId,
    required this.patientName,
    required this.assignedAt,
  });

  factory CustomExerciseAssignment.fromJson(Map<String, dynamic> json) {
    final assignmentId = json['assignmentId'];
    final exerciseId = json['exerciseId'];
    final exerciseName = json['exerciseName'];
    final exerciseDescription = json['exerciseDescription'];
    final therapistId = json['therapistId'];
    final therapistName = json['therapistName'];
    final patientId = json['patientId'];
    final patientName = json['patientName'];
    final assignedAt = json['assignedAt'];
    if (assignmentId == null ||
        exerciseId is! String ||
        exerciseName is! String ||
        exerciseDescription is! String ||
        therapistId == null ||
        therapistName is! String ||
        patientId == null ||
        patientName is! String ||
        assignedAt is! String) {
      throw const FormatException('自訂動作指派資料格式錯誤');
    }
    return CustomExerciseAssignment(
      assignmentId: assignmentId.toString(),
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      exerciseDescription: exerciseDescription,
      therapistId: therapistId.toString(),
      therapistName: therapistName,
      patientId: patientId.toString(),
      patientName: patientName,
      assignedAt: DateTime.parse(assignedAt),
    );
  }
}
