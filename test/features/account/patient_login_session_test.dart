import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/account/auth_service.dart';
import 'package:flutter_body/features/account/patient_login_session.dart';
import 'package:flutter_body/features/account/user_role.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.role = null;
    AppSession.userId = null;
    AppSession.name = null;
    AppSession.email = null;
    AppSession.bindingCode = null;
    AppSession.friendCode = null;
    AppSession.customExerciseToken = null;
  });

  test('Google result saves the existing PATIENT AppSession contract',
      () async {
    const googleIdToken = 'must-never-be-persisted';
    final result = LoginResult.success(
      userId: '12',
      name: '王小明',
      email: 'patient@example.com',
      bindingCode: 'ABC12345',
      friendCode: 'XYZ12345',
      customExerciseToken: 'backend-hmac-token',
      backendRole: 'PATIENT',
    );

    await PatientLoginSession.save(result);

    expect(AppSession.role, UserRole.patient);
    expect(AppSession.userId, '12');
    expect(AppSession.bindingCode, 'ABC12345');
    expect(AppSession.friendCode, 'XYZ12345');
    expect(AppSession.customExerciseToken, 'backend-hmac-token');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getKeys(), isNot(contains('google_id_token')));
    expect(preferences.getKeys(), isNot(contains('idToken')));
    expect(preferences.getKeys().map(preferences.get).contains(googleIdToken),
        isFalse);
  });

  test('non-PATIENT backend response is never saved', () async {
    final result = LoginResult.success(
      userId: '3',
      name: '治療師',
      email: 'therapist@example.com',
      bindingCode: null,
      customExerciseToken: 'token',
      backendRole: 'THERAPIST',
    );

    await expectLater(
      PatientLoginSession.save(result),
      throwsA(isA<PatientRoleException>()),
    );
    expect(AppSession.userId, isNull);
  });

  test('missing backend HMAC token is never saved as a patient session',
      () async {
    final result = LoginResult.success(
      userId: '12',
      name: '患者',
      email: 'patient@example.com',
      bindingCode: 'ABC12345',
      customExerciseToken: null,
      backendRole: 'PATIENT',
    );

    await expectLater(
      PatientLoginSession.save(result),
      throwsA(isA<InvalidPatientSessionException>()),
    );
    expect(AppSession.userId, isNull);
  });
}
