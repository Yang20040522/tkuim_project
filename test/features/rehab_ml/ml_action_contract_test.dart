import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/features/account/app_session.dart';
import 'package:flutter_body/features/rehab_ml/ml_action_definition.dart';
import 'package:flutter_body/features/rehab_ml/ml_research_api.dart';
import 'package:flutter_body/features/rehab_ml/ml_research_sync.dart';
import 'package:flutter_body/features/rehab_ml/ml_sample_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// No synthetic definition is added to the production registry.
const synthetic = MlActionDefinition(
  actionId: 'synthetic_test_only',
  version: 'synthetic-v1',
  displayName: '測試契約',
  featureNames: ['duration_seconds'],
  labels: {'test_match': '測試標籤'},
);

class _Sample implements MlResearchSample {
  _Sample(this.payload);
  final Map<String, Object> payload;
  @override
  String get id => payload['sampleId'] as String;
  @override
  Map<String, Object> toJson() => payload;
}

Map<String, Object> payload(MlActionDefinition action) => {
      'actionId': action.actionId,
      'schemaVersion': 1,
      'actionDefinitionVersion': action.version,
      'sampleId': 'synthetic_1',
      'subjectId': 'fake_subject',
      'capturedAt': '2026-10-03T00:00:00Z',
      'movementSide': 'left',
      'cameraView': 'front',
      'segment': {'startMs': 0, 'endMs': 300},
      'featureNames': action.featureNames,
      'features': action == synthetic ? [0.3] : [-0.5, 180, 180, 0, 0.3],
      'frames': [
        for (var t = 0; t <= 300; t += 100)
          {
            'timestampMs': t,
            'landmarks': [
              for (var i = 0; i < 17; i++) [0.1, 0.2]
            ],
            'confidence': List.filled(17, 0.9),
            'angles': <String, Object>{},
          }
      ],
    };

void main() {
  test('legacy schema1 accepted; wrong action/version/order rejected', () {
    final legacy = payload(MlActionRegistry.standingKneeRaise)
      ..remove('actionDefinitionVersion');
    expect(MlActionRegistry.production.forSample(legacy), isNotNull);
    legacy['actionDefinitionVersion'] = 'different-v1';
    expect(MlActionRegistry.production.forSample(legacy), isNull);
    expect(MlActionRegistry.production.forSample(payload(synthetic)), isNull);
    final wrong = payload(MlActionRegistry.standingKneeRaise)
      ..['featureNames'] = ['duration_seconds'];
    expect(MlActionRegistry.production.forSample(wrong), isNull);
  });

  test('injected second action shares local save/list/export/delete and sync',
      () async {
    SharedPreferences.setMockInitialValues({});
    AppSession.userId = '1';
    AppSession.customExerciseToken = 'fake-token';
    final directory = await Directory.systemTemp.createTemp('g35-contract-');
    addTearDown(() async {
      AppSession.userId = null;
      AppSession.customExerciseToken = null;
      await directory.delete(recursive: true);
    });
    final registry =
        MlActionRegistry([MlActionRegistry.standingKneeRaise, synthetic]);
    final local = MlSampleRepository(
        directoryProvider: () async => directory, actions: registry);
    final sample = _Sample(payload(synthetic));
    await local.save(sample);
    expect((await local.list()).single['actionId'], synthetic.actionId);
    expect(
        jsonDecode(utf8.decode(await local.exportJson(sample.id)))['features'],
        [0.3]);
    final uploads = <Map<String, dynamic>>[];
    final remote = MlResearchApi(
        baseUrl: 'https://example.invalid',
        client: MockClient((request) async {
          expect(request.headers['X-Custom-Exercise-Token'], 'fake-token');
          if (request.url.path.endsWith('/consent')) {
            return http.Response(
                jsonEncode({
                  'active': true,
                  'available': true,
                  'currentVersion': 'test-v1'
                }),
                200);
          }
          uploads.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('{}', 200);
        }));
    final queue = MlResearchSync(remote: remote, local: local);
    await queue.enqueue(sample.id);
    await queue.sync();
    await queue.sync();
    expect(uploads, hasLength(1));
    expect(uploads.single['actionDefinitionVersion'], synthetic.version);
    await local.delete(sample.id);
    expect(await local.list(), isEmpty);
  });

  test('production storage never accepts synthetic or path traversal sample',
      () async {
    final directory = await Directory.systemTemp.createTemp('g35-production-');
    addTearDown(() => directory.delete(recursive: true));
    final local = MlSampleRepository(directoryProvider: () async => directory);
    await expectLater(
        local.save(_Sample(payload(synthetic))), throwsFormatException);
    final bad = payload(MlActionRegistry.standingKneeRaise)
      ..['sampleId'] = '../escape';
    await expectLater(local.save(_Sample(bad)), throwsFormatException);
  });
}
