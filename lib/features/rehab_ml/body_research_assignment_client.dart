import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/api_config.dart';
import 'research_owner_scope.dart';
import 'ml_research_api.dart';

/// Resolves the real assigned catalog ID; never infers it from a Flutter index.
Future<String?> assignedStandingBodyExercise({http.Client? client}) async {
  return assignedBodyExercise('站姿抬腳式訓練', client: client);
}

Future<String?> assignedBodyExercise(String catalogName, {http.Client? client}) async {
  final owner = ResearchOwnerScope.capture();
  owner.check(requireToken: true);
  final transport = client ?? http.Client();
  try {
    final response = await transport.get(
        Uri.parse('${ApiConfig.baseUrl}/api/patient/assigned-exercises'),
        headers: {
          'Accept': 'application/json',
          'X-User-Id': owner.userId,
          'X-Custom-Exercise-Token': owner.token!
        }).timeout(const Duration(seconds: 20));
    owner.check(requireToken: true);
    if (response.statusCode != 200) {
      throw MlResearchException.fromResponse(response.statusCode);
    }
    final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! List) {
      throw const FormatException('Invalid assignment response');
    }
    for (final dynamic item in data) {
      if (item is Map &&
          item['type'] == 'DEFAULT' &&
          item['assigned'] == true &&
          item['name'] == catalogName &&
          item['id'] != null) {
        return item['id'].toString();
      }
    }
    return null;
  } finally {
    if (client == null) transport.close();
  }
}
