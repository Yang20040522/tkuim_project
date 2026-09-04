import 'app_session.dart';
import 'auth_service.dart';
import 'user_role.dart';

class PatientLoginSession {
  const PatientLoginSession._();

  static Future<void> save(
    LoginResult result, {
    String fallbackName = '',
    String fallbackEmail = '',
  }) async {
    if (!result.success || result.backendRole?.toUpperCase() != 'PATIENT') {
      throw const PatientRoleException();
    }
    if ((result.userId ?? '').trim().isEmpty ||
        (result.customExerciseToken ?? '').trim().isEmpty) {
      throw const InvalidPatientSessionException();
    }
    await AppSession.save(
      role: UserRole.patient,
      userId: result.userId ?? '',
      name: result.name ?? fallbackName,
      email: result.email ?? fallbackEmail,
      accountId: result.accountId,
      bindingCode: result.bindingCode,
      customExerciseToken: result.customExerciseToken,
    );
  }
}

class PatientRoleException implements Exception {
  const PatientRoleException();
}

class InvalidPatientSessionException implements Exception {
  const InvalidPatientSessionException();
}
