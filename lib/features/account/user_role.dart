// lib/features/account/user_role.dart
enum UserRole {
  therapist, // 治療師
  patient, // 病人
}

extension UserRoleLabel on UserRole {
  String get label {
    switch (this) {
      case UserRole.therapist:
        return '治療師';
      case UserRole.patient:
        return '病人';
    }
  }
}