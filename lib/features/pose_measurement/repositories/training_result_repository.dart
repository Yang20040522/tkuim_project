import '../../../models/training_session_result.dart';

abstract class TrainingResultRepository {
  Future<TrainingSessionResult> save(TrainingSessionResult result);
  Future<List<TrainingSessionResult>> getMyResults();
  Future<List<TrainingSessionResult>> getPatientResults(String patientId);
}
