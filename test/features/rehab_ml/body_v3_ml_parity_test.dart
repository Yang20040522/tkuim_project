import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_body/features/rehab_ml/body_research_extended_features.dart';
import 'package:flutter_body/features/rehab_ml/body_research_feature_extractor.dart';
import 'package:flutter_body/models/body_pose_observation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture =
      jsonDecode(File('test/fixtures/body_v3_parity.json').readAsStringSync())
          as Map<String, dynamic>;
  final output = <String, Object>{};
  for (final raw in fixture['cases'] as List) {
    final c = raw as Map<String, dynamic>;
    test('body v3 shared parity fixture ${c['name']}', () {
      final frames = <BodyPoseObservation>[];
      final steps = c['steps'] as List;
      for (var i = 0; i < steps.length; i++) {
        final step = steps[i] as Map<String, dynamic>;
        final points = (fixture['baseKeypoints'] as List)
            .map<Offset?>((p) =>
                Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
            .toList();
        final scores = List<double?>.filled(17, 1.4);
        for (final entry
            in (step['points'] as Map<String, dynamic>? ?? {}).entries) {
          points[int.parse(entry.key)] = Offset(
              (entry.value[0] as num).toDouble(),
              (entry.value[1] as num).toDouble());
        }
        for (final index in step['missing'] as List? ?? []) {
          points[index as int] = null;
          scores[index] = null;
        }
        frames.add(BodyPoseObservation(
            frameId: i,
            streamSessionId: 'synthetic',
            receivedAtMs: step['timeMs'] as int? ?? i * 100,
            imageWidth: c['width'] as int? ?? 640,
            imageHeight: c['height'] as int? ?? 480,
            keypoints: points,
            scores: scores,
            source: 'tv_pi',
            mirrored: c['mirrored'] as bool? ?? false,
            rotationDegrees: c['rotation'] as int? ?? 0));
      }
      final result = BodyResearchFeatureExtractor.extract(frames, 'left');
      final extended = BodyResearchExtendedFeatures.extract(frames, 'left');
      expect(BodyResearchFeatureExtractor.version, fixture['extractorVersion']);
      expect(BodyResearchExtendedFeatures.version, fixture['extendedVersion']);
      expect(result.status,
          c['name'] == 'unavailable' ? 'unavailable' : 'available');
      expect(extended.take(5), result.values);
      if (result.status == 'unavailable')
        expect(extended, everyElement(isNull));
      output[c['name'] as String] = {
        'values': result.values,
        'extendedValues': extended,
        'validFrameRatio': result.validFrameRatio,
        'status': result.status
      };
    });
  }
  tearDownAll(() {
    final dir = Directory('.dart_tool/body-r4')..createSync(recursive: true);
    File('${dir.path}/dart_parity.json').writeAsStringSync(jsonEncode({
      'fixture': fixture,
      'extractorVersion': BodyResearchFeatureExtractor.version,
      'featureNames': BodyResearchFeatureExtractor.featureNames,
      'extendedNames': BodyResearchExtendedFeatures.names,
      'results': output,
    }));
  });
}
