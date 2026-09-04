class TherapistPatientPreview {
  final String patientId;
  final String patientName;
  final String patientEmail;

  const TherapistPatientPreview({
    required this.patientId,
    required this.patientName,
    required this.patientEmail,
  });

  factory TherapistPatientPreview.fromJson(Map<String, dynamic> json) {
    final patientId = json['patientId'];
    final patientName = json['patientName'];
    final patientEmail = json['patientEmail'];
    if (patientId == null ||
        patientName is! String ||
        patientEmail is! String) {
      throw const FormatException('患者資料格式錯誤');
    }
    return TherapistPatientPreview(
      patientId: patientId.toString(),
      patientName: patientName,
      patientEmail: patientEmail,
    );
  }
}

class TherapistPatient extends TherapistPatientPreview {
  final String relationship;
  final DateTime? boundAt;

  const TherapistPatient({
    required super.patientId,
    required super.patientName,
    required super.patientEmail,
    required this.relationship,
    required this.boundAt,
  });

  factory TherapistPatient.fromJson(Map<String, dynamic> json) {
    final preview = TherapistPatientPreview.fromJson(json);
    final relationship = json['relationship'];
    final rawBoundAt = json['boundAt'];
    if (relationship is! String ||
        (rawBoundAt != null && rawBoundAt is! String)) {
      throw const FormatException('患者綁定資料格式錯誤');
    }
    return TherapistPatient(
      patientId: preview.patientId,
      patientName: preview.patientName,
      patientEmail: preview.patientEmail,
      relationship: relationship,
      boundAt: rawBoundAt == null ? null : DateTime.tryParse(rawBoundAt),
    );
  }
}
