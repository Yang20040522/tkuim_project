import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_body/core/ui/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_body/features/account/account_info_screen.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/account/bind_patient_page.dart';
import 'package:flutter_body/features/account/patient_management_page.dart';
import 'package:flutter_body/features/account/repositories/therapist_patient_repository.dart';
import 'package:flutter_body/features/account/services/therapist_patient_api_client.dart';
import 'package:flutter_body/features/account/therapist_home_screen.dart';
import 'package:flutter_body/features/account/user_role.dart';
import 'package:flutter_body/features/custom_exercise/repositories/unified_exercise_assignment_repository.dart';
import 'package:flutter_body/features/custom_exercise/services/custom_exercise_api_client.dart';
import 'package:flutter_body/features/custom_exercise/unified_exercise_assignment_page.dart';
import 'package:flutter_body/models/assignable_exercise.dart';
import 'package:flutter_body/models/custom_exercise_assignment.dart';
import 'package:flutter_body/models/custom_rehab_exercise.dart';
import 'package:flutter_body/models/therapist_patient.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.role = null;
    AppSession.userId = null;
    AppSession.name = null;
    AppSession.email = null;
    AppSession.bindingCode = null;
    AppSession.customExerciseToken = null;
  });

  group('Therapist patient API', () {
    test('lists patients with authenticated therapist headers', () async {
      late http.Request captured;
      final client = TherapistPatientApiClient(
        baseUrl: 'https://example.test',
        userIdProvider: () => '7',
        identityTokenProvider: () => 'signed-token',
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response.bytes(
            utf8.encode(jsonEncode([_patientJson()])),
            200,
          );
        }),
      );

      final patients = await client.getPatients();

      expect(captured.url.path, '/api/therapist/patients');
      expect(captured.headers['X-User-Id'], '7');
      expect(captured.headers['X-Custom-Exercise-Token'], 'signed-token');
      expect(patients.single.patientEmail, 'patient@example.com');
    });

    test('lookup, bind, and unbind use code-only secure routes', () async {
      final requests = <http.Request>[];
      final client = TherapistPatientApiClient(
        baseUrl: 'https://example.test',
        userIdProvider: () => '7',
        identityTokenProvider: () => 'signed-token',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.method == 'DELETE') return http.Response('', 204);
          if (request.url.path.endsWith('/lookup')) {
            return http.Response(
              jsonEncode(_previewJson()),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response.bytes(
            utf8.encode(jsonEncode(_patientJson())),
            200,
          );
        }),
      );

      await client.lookupPatient(' ABC12345 ');
      await client.bindPatient(' ABC12345 ');
      await client.unbindPatient('15');

      expect(requests.map((item) => item.method), ['GET', 'POST', 'DELETE']);
      expect(requests.first.url.queryParameters['bindingCode'], 'ABC12345');
      expect(jsonDecode(requests[1].body), {'bindingCode': 'ABC12345'});
      expect(requests[2].url.path, '/api/therapist/patients/15');
    });
  });

  group('Patient binding code', () {
    testWidgets('patient account displays and copies backend binding code',
        (tester) async {
      String? copiedCode;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedCode =
                Map<String, dynamic>.from(call.arguments as Map)['text']
                    as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      AppSession.role = UserRole.patient;
      AppSession.bindingCode = 'ABC12345';
      await tester.pumpWidget(
        const MaterialApp(home: AccountInfoScreen()),
      );
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('patient-binding-code-card')), findsOneWidget);
      expect(find.text('ABC12345'), findsOneWidget);
      expect(find.text('請將此綁定碼提供給您的治療師'), findsOneWidget);

      final copyButton = find.byKey(const Key('copy-patient-binding-code'));
      await tester.ensureVisible(copyButton);
      await tester.tap(copyButton);
      await tester.pump(const Duration(milliseconds: 100));
      expect(copiedCode, 'ABC12345');
      expect(find.text('綁定碼已複製'), findsOneWidget);
    });
  });

  group('Therapist patient management widgets', () {
    testWidgets('therapist home exposes patient management entry',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: TherapistHomeScreen()));
      expect(find.byKey(const Key('open-patient-management')), findsOneWidget);
      await tester.tap(find.byKey(const Key('open-patient-management')));
      await tester.pumpAndSettle();
      expect(find.text('患者管理'), findsOneWidget);
    });

    testWidgets('patient list displays identity, relationship, and bound time',
        (tester) async {
      final repository = _FakeTherapistPatientRepository()
        ..patients = [_patient()];
      await tester.pumpWidget(
        MaterialApp(home: PatientManagementPage(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.text('王小明'), findsOneWidget);
      expect(find.text('patient@example.com'), findsOneWidget);
      expect(find.text('THERAPIST'), findsOneWidget);
      expect(find.textContaining('2026/09/04'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('王小明')).style?.color,
        AppColors.primaryText,
      );
      expect(
        tester.widget<Text>(find.text('patient@example.com')).style?.color,
        AppColors.secondaryText,
      );
    });

    testWidgets('bind form searches and previews patient', (tester) async {
      final repository = _FakeTherapistPatientRepository();
      await tester.pumpWidget(
        MaterialApp(home: BindPatientPage(repository: repository)),
      );

      await tester.enterText(
        find.byKey(const Key('patient-binding-code-field')),
        'ABC12345',
      );
      await tester.tap(find.byKey(const Key('search-patient-binding-code')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('patient-binding-preview')), findsOneWidget);
      expect(find.text('王小明'), findsOneWidget);
      expect(repository.lookupCodes, ['ABC12345']);
    });

    testWidgets('successful bind returns and reloads patient list',
        (tester) async {
      final repository = _FakeTherapistPatientRepository();
      await tester.pumpWidget(
        MaterialApp(home: PatientManagementPage(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(repository.getPatientsCalls, 1);

      await tester.tap(find.byKey(const Key('bind-patient-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('patient-binding-code-field')),
        'ABC12345',
      );
      await tester.tap(find.byKey(const Key('search-patient-binding-code')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-bind-patient')));
      await tester.pumpAndSettle();

      expect(repository.getPatientsCalls, 2);
      expect(find.byKey(const Key('therapist-patient-15')), findsOneWidget);
    });

    testWidgets('duplicate bind error is shown without raw exception',
        (tester) async {
      final repository = _FakeTherapistPatientRepository()
        ..bindError = const CustomExerciseApiException('此患者已與目前帳號建立綁定');
      await tester.pumpWidget(
        MaterialApp(home: BindPatientPage(repository: repository)),
      );

      await _searchAndConfirm(tester);

      expect(find.text('此患者已與目前帳號建立綁定'), findsOneWidget);
      expect(find.byKey(const Key('bind-patient-error')), findsOneWidget);
    });

    testWidgets('invalid binding code error is shown', (tester) async {
      final repository = _FakeTherapistPatientRepository()
        ..lookupError = const CustomExerciseApiException('找不到此綁定碼');
      await tester.pumpWidget(
        MaterialApp(home: BindPatientPage(repository: repository)),
      );

      await tester.enterText(
        find.byKey(const Key('patient-binding-code-field')),
        'INVALID',
      );
      await tester.tap(find.byKey(const Key('search-patient-binding-code')));
      await tester.pumpAndSettle();

      expect(find.text('找不到此綁定碼'), findsOneWidget);
    });

    testWidgets('unbind removes only selected patient after confirmation',
        (tester) async {
      final repository = _FakeTherapistPatientRepository()
        ..patients = [_patient()];
      await tester.pumpWidget(
        MaterialApp(home: PatientManagementPage(repository: repository)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('unbind-patient-15')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-unbind-patient')));
      await tester.pumpAndSettle();

      expect(repository.unboundIds, ['15']);
      expect(find.byKey(const Key('therapist-patient-15')), findsNothing);
      expect(find.byKey(const Key('patient-management-empty')), findsOneWidget);
    });

    testWidgets('empty state is explicit and can start bind flow',
        (tester) async {
      final repository = _FakeTherapistPatientRepository();
      await tester.pumpWidget(
        MaterialApp(home: PatientManagementPage(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('尚無已綁定患者'), findsOneWidget);
      expect(find.byKey(const Key('patient-management-empty')), findsOneWidget);
    });

    testWidgets('network error offers retry and reloads', (tester) async {
      final repository = _FakeTherapistPatientRepository()
        ..getPatientsError = StateError('offline');
      await tester.pumpWidget(
        MaterialApp(home: PatientManagementPage(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('patient-management-error')), findsOneWidget);

      repository.getPatientsError = null;
      repository.patients = [_patient()];
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('therapist-patient-15')), findsOneWidget);
    });

    testWidgets('assignment page sees patient immediately after bind',
        (tester) async {
      final shared = _SharedPatientState();
      final bindingRepository = _SharedBindingRepository(shared);
      final assignmentRepository = _SharedAssignmentRepository(shared);

      await bindingRepository.bindPatient('ABC12345');
      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedExerciseAssignmentPage(
            repository: assignmentRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('王小明'), findsOneWidget);
      expect(assignmentRepository.getPatientCalls, 1);
    });
  });
}

Future<void> _searchAndConfirm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('patient-binding-code-field')),
    'ABC12345',
  );
  await tester.tap(find.byKey(const Key('search-patient-binding-code')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('confirm-bind-patient')));
  await tester.pumpAndSettle();
}

Map<String, dynamic> _previewJson() => {
      'patientId': 15,
      'patientName': '王小明',
      'patientEmail': 'patient@example.com',
    };

Map<String, dynamic> _patientJson() => {
      ..._previewJson(),
      'relationship': 'THERAPIST',
      'boundAt': '2026-09-04T10:30:00',
    };

TherapistPatientPreview _preview() => const TherapistPatientPreview(
      patientId: '15',
      patientName: '王小明',
      patientEmail: 'patient@example.com',
    );

TherapistPatient _patient() => TherapistPatient(
      patientId: '15',
      patientName: '王小明',
      patientEmail: 'patient@example.com',
      relationship: 'THERAPIST',
      boundAt: DateTime(2026, 9, 4, 10, 30),
    );

class _FakeTherapistPatientRepository implements TherapistPatientRepository {
  List<TherapistPatient> patients = [];
  Object? getPatientsError;
  Object? lookupError;
  Object? bindError;
  int getPatientsCalls = 0;
  final List<String> lookupCodes = [];
  final List<String> unboundIds = [];

  @override
  Future<TherapistPatient> bindPatient(String bindingCode) async {
    if (bindError != null) throw bindError!;
    final patient = _patient();
    patients = [patient];
    return patient;
  }

  @override
  Future<List<TherapistPatient>> getPatients() async {
    getPatientsCalls++;
    if (getPatientsError != null) throw getPatientsError!;
    return List.unmodifiable(patients);
  }

  @override
  Future<TherapistPatientPreview> lookupPatient(String bindingCode) async {
    lookupCodes.add(bindingCode);
    if (lookupError != null) throw lookupError!;
    return _preview();
  }

  @override
  Future<void> unbindPatient(String patientId) async {
    unboundIds.add(patientId);
    patients = patients
        .where((patient) => patient.patientId != patientId)
        .toList(growable: false);
  }
}

class _SharedPatientState {
  final List<TherapistPatient> patients = [];
}

class _SharedBindingRepository implements TherapistPatientRepository {
  final _SharedPatientState state;

  _SharedBindingRepository(this.state);

  @override
  Future<TherapistPatient> bindPatient(String bindingCode) async {
    final patient = _patient();
    state.patients.add(patient);
    return patient;
  }

  @override
  Future<List<TherapistPatient>> getPatients() async => state.patients;

  @override
  Future<TherapistPatientPreview> lookupPatient(String bindingCode) async =>
      _preview();

  @override
  Future<void> unbindPatient(String patientId) async {
    state.patients.removeWhere((patient) => patient.patientId == patientId);
  }
}

class _SharedAssignmentRepository
    implements UnifiedExerciseAssignmentRepository {
  final _SharedPatientState state;
  int getPatientCalls = 0;

  _SharedAssignmentRepository(this.state);

  @override
  Future<List<AssignablePatient>> getAssignablePatients() async {
    getPatientCalls++;
    return state.patients
        .map(
          (patient) => AssignablePatient(
            patientId: patient.patientId,
            patientName: patient.patientName,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<AssignableExercise>> getAssignableExercises(
    String patientId,
  ) async =>
      const [];

  @override
  Future<AssignableExercise> assign(
    AssignableExercise exercise,
    String patientId,
  ) async =>
      exercise;

  @override
  Future<void> unassign(
    AssignableExercise exercise,
    String patientId,
  ) async {}

  @override
  Future<List<AssignableExercise>> getPatientAssignedExercises() async =>
      const [];

  @override
  Future<CustomRehabExercise?> getPatientCustomExercise(
    String exerciseId,
  ) async =>
      null;
}
