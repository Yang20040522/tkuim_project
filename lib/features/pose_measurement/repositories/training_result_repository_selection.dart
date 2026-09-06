import '../../../core/api_config.dart';
import '../../account/app_session.dart';
import '../services/training_result_api_client.dart';
import 'training_result_repository.dart';

final TrainingResultRepository trainingResultRepository =
    TrainingResultApiClient(
  baseUrl: ApiConfig.baseUrl,
  userIdProvider: () => AppSession.userId,
  identityTokenProvider: () => AppSession.customExerciseToken,
);
