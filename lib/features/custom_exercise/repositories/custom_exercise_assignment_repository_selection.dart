import '../../../core/api_config.dart';
import '../../account/app_session.dart';
import '../services/custom_exercise_assignment_api_client.dart';
import 'custom_exercise_assignment_repository.dart';
import 'remote_custom_exercise_assignment_repository.dart';

final CustomExerciseAssignmentRepository customExerciseAssignmentRepository =
    RemoteCustomExerciseAssignmentRepository(
  apiClient: CustomExerciseAssignmentApiClient(
    baseUrl: ApiConfig.baseUrl,
    userIdProvider: () => AppSession.userId,
    identityTokenProvider: () => AppSession.customExerciseToken,
  ),
);
