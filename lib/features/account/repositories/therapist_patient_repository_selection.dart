import '../../../core/api_config.dart';
import '../app_session.dart';
import '../services/therapist_patient_api_client.dart';
import 'remote_therapist_patient_repository.dart';
import 'therapist_patient_repository.dart';

final TherapistPatientRepository therapistPatientRepository =
    RemoteTherapistPatientRepository(
  apiClient: TherapistPatientApiClient(
    baseUrl: ApiConfig.baseUrl,
    userIdProvider: () => AppSession.userId,
    identityTokenProvider: () => AppSession.customExerciseToken,
  ),
);
