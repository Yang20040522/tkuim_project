import '../../../core/api_config.dart';
import '../../account/app_session.dart';
import '../services/unified_exercise_assignment_api_client.dart';
import 'remote_unified_exercise_assignment_repository.dart';
import 'unified_exercise_assignment_repository.dart';

final UnifiedExerciseAssignmentRepository unifiedExerciseAssignmentRepository =
    RemoteUnifiedExerciseAssignmentRepository(
  apiClient: UnifiedExerciseAssignmentApiClient(
    baseUrl: ApiConfig.baseUrl,
    userIdProvider: () => AppSession.userId,
    identityTokenProvider: () => AppSession.customExerciseToken,
  ),
);
