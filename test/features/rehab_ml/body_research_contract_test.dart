import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/features/rehab_ml/body_research_contract.dart';
import 'package:flutter_body/features/rehab_ml/body_research_assignment_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'body_research_owner_test.dart' show login;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Map<String, dynamic> fixture() =>
      jsonDecode(File('test/fixtures/body_attempt_v3_synthetic.json')
          .readAsStringSync()) as Map<String, dynamic>;
  test(
      'shared Dart/Java synthetic fixture validates; altered metadata rejected',
      () {
    final p = fixture();
    expect(BodyResearchContract.accepts(p), true);
    p['poseModelVersion'] = 'fake-world';
    expect(BodyResearchContract.accepts(p), false);
  });
  test(
      'phone source needs phone timing/platform; invalid points cannot be sanitized into acceptance',
      () {
    final p = fixture();
    p['source'] = 'phone';
    expect(BodyResearchContract.accepts(p), false);
    final bad = fixture();
    bad['frames'][0]['keypoints'][5] = [-1, 0];
    expect(BodyResearchContract.accepts(bad), false);
  });
  test(
      'assignment resolution uses persisted ID, authenticated headers, not list index',
      () async {
    login('synthetic');
    final client = MockClient((request) async {
      expect(request.url.path, '/api/patient/assigned-exercises');
      expect(request.headers['X-User-Id'], 'synthetic');
      expect(request.headers['X-Custom-Exercise-Token'], isNotEmpty);
      return http.Response(
          jsonEncode([
            {'type': 'DEFAULT', 'id': 7, 'name': '其他動作', 'assigned': true},
            {
              'type': 'CUSTOM',
              'id': 'custom99',
              'name': '站姿抬腳式訓練',
              'assigned': true
            },
            {'type': 'DEFAULT', 'id': 99, 'name': '站姿抬腳式訓練', 'assigned': true}
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    expect(await assignedStandingBodyExercise(client: client), '99');
    client.close();
  });
}
