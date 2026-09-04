import '../../../core/api_config.dart';
import '../../account/app_session.dart';
import '../services/custom_exercise_api_client.dart';
import 'custom_exercise_repository.dart';
import 'remote_custom_exercise_repository.dart';

/// 正式治療師流程的 remote persistence composition root。
///
/// LocalCustomExerciseRepository 仍保留作開發／緊急展示用途，但不會與 remote
/// 自動同步或自動上傳既有 SharedPreferences 資料。
final CustomExerciseRepository therapistCustomExerciseRepository =
    RemoteCustomExerciseRepository(
  apiClient: CustomExerciseApiClient(
    baseUrl: ApiConfig.baseUrl,
    userIdProvider: () => AppSession.userId,
    identityTokenProvider: () => AppSession.customExerciseToken,
  ),
);
