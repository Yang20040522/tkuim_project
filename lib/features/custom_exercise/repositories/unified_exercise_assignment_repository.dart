import '../../../models/assignable_exercise.dart';
import '../../../models/custom_exercise_assignment.dart';
import '../../../models/custom_rehab_exercise.dart';

abstract class UnifiedExerciseAssignmentRepository {
  Future<List<AssignablePatient>> getAssignablePatients();

  Future<List<AssignableExercise>> getAssignableExercises(String patientId);

  Future<AssignableExercise> assign(
    AssignableExercise exercise,
    String patientId,
  );

  Future<void> unassign(
    AssignableExercise exercise,
    String patientId,
  );

  Future<List<AssignableExercise>> getPatientAssignedExercises();

  Future<CustomRehabExercise?> getPatientCustomExercise(String exerciseId);
}
