import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/account/user_role.dart';
import 'package:flutter_body/core/custom_exercise_development_fallback.dart';
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

  test('開發 fallback 允許治療師在缺少 token 時完成登入', () {
    expect(
      CustomExerciseDevelopmentFallback.canCompleteTherapistLogin(null),
      isTrue,
    );
    expect(
      CustomExerciseDevelopmentFallback.normalizeToken('   '),
      isNull,
    );
    expect(
      CustomExerciseDevelopmentFallback.normalizeToken(' signed-token '),
      'signed-token',
    );
  });
}
