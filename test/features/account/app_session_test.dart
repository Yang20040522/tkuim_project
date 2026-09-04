import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/account/user_role.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.role = null;
    AppSession.userId = null;
    AppSession.name = null;
    AppSession.email = null;
    AppSession.accountId = null;
    AppSession.bindingCode = null;
    AppSession.customExerciseToken = null;
  });

  test('AppSession 重載後保留 Custom Exercise identity token', () async {
    await AppSession.save(
      role: UserRole.therapist,
      userId: '7',
      name: '治療師',
      email: 'therapist@example.com',
      customExerciseToken: 'signed-token',
    );

    AppSession.role = null;
    AppSession.userId = null;
    AppSession.name = null;
    AppSession.email = null;
    AppSession.customExerciseToken = null;
    await AppSession.load();

    expect(AppSession.role, UserRole.therapist);
    expect(AppSession.userId, '7');
    expect(AppSession.customExerciseToken, 'signed-token');
  });

  test('AppSession clear 同時移除 Custom Exercise identity token', () async {
    await AppSession.save(
      role: UserRole.therapist,
      userId: '7',
      customExerciseToken: 'signed-token',
    );

    await AppSession.clear();
    await AppSession.load();

    expect(AppSession.userId, isNull);
    expect(AppSession.customExerciseToken, isNull);
  });

  test('AppSession 重載後保留患者 binding code', () async {
    await AppSession.save(
      role: UserRole.patient,
      userId: '15',
      bindingCode: 'ABC12345',
    );

    AppSession.bindingCode = null;
    await AppSession.load();

    expect(AppSession.bindingCode, 'ABC12345');
  });

  test('AppSession 重載後保留帳號 ID', () async {
    await AppSession.save(
      role: UserRole.patient,
      userId: '15',
      accountId: 'rehab123',
    );

    AppSession.accountId = null;
    await AppSession.load();

    expect(AppSession.accountId, 'rehab123');
  });

  test('AppSession 允許 null token 並清除前一次的 token', () async {
    await AppSession.save(
      role: UserRole.therapist,
      userId: '7',
      customExerciseToken: 'old-token',
    );
    await AppSession.save(
      role: UserRole.therapist,
      userId: '7',
      customExerciseToken: null,
    );

    AppSession.customExerciseToken = 'stale-memory-token';
    await AppSession.load();

    expect(AppSession.role, UserRole.therapist);
    expect(AppSession.userId, '7');
    expect(AppSession.customExerciseToken, isNull);
  });
}
