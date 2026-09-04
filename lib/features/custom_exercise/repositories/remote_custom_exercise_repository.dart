import '../../../models/custom_rehab_exercise.dart';
import '../services/custom_exercise_api_client.dart';
import 'custom_exercise_repository.dart';

class RemoteCustomExerciseRepository implements CustomExerciseRepository {
  final CustomExerciseApiClient _apiClient;

  RemoteCustomExerciseRepository({required CustomExerciseApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<void> saveExercise(CustomRehabExercise exercise) async {
    await _apiClient.saveExercise(exercise);
  }

  @override
  Future<CustomRehabExercise?> getExercise(String id) =>
      _apiClient.getExercise(id);

  @override
  Future<List<CustomRehabExercise>> getAllExercises() =>
      _apiClient.getAllExercises();

  @override
  Future<void> updateExercise(CustomRehabExercise exercise) =>
      saveExercise(exercise);

  @override
  Future<void> deleteExercise(String id) => _apiClient.deleteExercise(id);
}
