import '../../../models/custom_exercise_assignment.dart';
import '../../../models/custom_rehab_exercise.dart';

abstract class CustomExerciseAssignmentRepository {
  Future<List<AssignablePatient>> getAssignablePatients();

  Future<List<CustomExerciseAssignment>> getExerciseAssignments(
    String exerciseId,
  );

  Future<CustomExerciseAssignment> assign(
    String exerciseId,
    String patientId,
  );

  Future<void> unassign(String exerciseId, String patientId);

  Future<List<CustomRehabExercise>> getPatientExercises();

  Future<CustomRehabExercise?> getPatientExercise(String exerciseId);
}
