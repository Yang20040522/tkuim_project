import '../../../models/custom_exercise_assignment.dart';
import '../../../models/custom_rehab_exercise.dart';
import '../services/custom_exercise_assignment_api_client.dart';
import 'custom_exercise_assignment_repository.dart';

class RemoteCustomExerciseAssignmentRepository
    implements CustomExerciseAssignmentRepository {
  final CustomExerciseAssignmentApiClient _apiClient;

  RemoteCustomExerciseAssignmentRepository({
    required CustomExerciseAssignmentApiClient apiClient,
  }) : _apiClient = apiClient;

  @override
  Future<CustomExerciseAssignment> assign(
    String exerciseId,
    String patientId,
  ) =>
      _apiClient.assign(exerciseId, patientId);

  @override
  Future<List<AssignablePatient>> getAssignablePatients() =>
      _apiClient.getAssignablePatients();

  @override
  Future<List<CustomExerciseAssignment>> getExerciseAssignments(
    String exerciseId,
  ) =>
      _apiClient.getExerciseAssignments(exerciseId);

  @override
  Future<CustomRehabExercise?> getPatientExercise(String exerciseId) =>
      _apiClient.getPatientExercise(exerciseId);

  @override
  Future<List<CustomRehabExercise>> getPatientExercises() =>
      _apiClient.getPatientExercises();

  @override
  Future<void> unassign(String exerciseId, String patientId) =>
      _apiClient.unassign(exerciseId, patientId);
}
