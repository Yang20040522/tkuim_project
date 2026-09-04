import '../../../models/assignable_exercise.dart';
import '../../../models/custom_exercise_assignment.dart';
import '../../../models/custom_rehab_exercise.dart';
import '../services/unified_exercise_assignment_api_client.dart';
import 'unified_exercise_assignment_repository.dart';

class RemoteUnifiedExerciseAssignmentRepository
    implements UnifiedExerciseAssignmentRepository {
  final UnifiedExerciseAssignmentApiClient _apiClient;

  RemoteUnifiedExerciseAssignmentRepository({
    required UnifiedExerciseAssignmentApiClient apiClient,
  }) : _apiClient = apiClient;

  @override
  Future<AssignableExercise> assign(
    AssignableExercise exercise,
    String patientId,
  ) =>
      _apiClient.assign(exercise, patientId);

  @override
  Future<List<AssignableExercise>> getAssignableExercises(String patientId) =>
      _apiClient.getAssignableExercises(patientId);

  @override
  Future<List<AssignablePatient>> getAssignablePatients() =>
      _apiClient.getAssignablePatients();

  @override
  Future<List<AssignableExercise>> getPatientAssignedExercises() =>
      _apiClient.getPatientAssignedExercises();

  @override
  Future<CustomRehabExercise?> getPatientCustomExercise(String exerciseId) =>
      _apiClient.getPatientCustomExercise(exerciseId);

  @override
  Future<void> unassign(
    AssignableExercise exercise,
    String patientId,
  ) =>
      _apiClient.unassign(exercise, patientId);
}
