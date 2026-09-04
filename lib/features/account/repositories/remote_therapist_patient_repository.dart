import '../../../models/therapist_patient.dart';
import '../services/therapist_patient_api_client.dart';
import 'therapist_patient_repository.dart';

class RemoteTherapistPatientRepository implements TherapistPatientRepository {
  final TherapistPatientApiClient _apiClient;

  RemoteTherapistPatientRepository({
    required TherapistPatientApiClient apiClient,
  }) : _apiClient = apiClient;

  @override
  Future<TherapistPatient> bindPatient(String bindingCode) =>
      _apiClient.bindPatient(bindingCode);

  @override
  Future<List<TherapistPatient>> getPatients() => _apiClient.getPatients();

  @override
  Future<TherapistPatientPreview> lookupPatient(String bindingCode) =>
      _apiClient.lookupPatient(bindingCode);

  @override
  Future<void> unbindPatient(String patientId) =>
      _apiClient.unbindPatient(patientId);
}
