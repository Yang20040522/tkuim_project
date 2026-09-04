import '../../../models/therapist_patient.dart';

abstract class TherapistPatientRepository {
  Future<List<TherapistPatient>> getPatients();

  Future<TherapistPatientPreview> lookupPatient(String bindingCode);

  Future<TherapistPatient> bindPatient(String bindingCode);

  Future<void> unbindPatient(String patientId);
}
