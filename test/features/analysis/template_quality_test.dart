import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_body/features/analysis/models/template_quality.dart';

void main() {
  test('accepts a sufficiently complete one-shot sample', () {
    final quality = TemplateQualityValidator.evaluate(
      segmentDuration: const Duration(seconds: 2),
      attemptedFrameCount: 8,
      validFrameCount: 7,
      normalizedFrameCount: 7,
      averageBodyConfidence: 0.8,
      movementIntensity: 0.05,
      detectedRepetitions: 1,
    );

    expect(quality.isAcceptable, isTrue);
    expect(quality.issues, isEmpty);
  });

  test('reports all minimum quality-gate failures', () {
    final quality = TemplateQualityValidator.evaluate(
      segmentDuration: const Duration(milliseconds: 300),
      attemptedFrameCount: 4,
      validFrameCount: 1,
      normalizedFrameCount: 0,
      averageBodyConfidence: 0.1,
      movementIntensity: 0,
      detectedRepetitions: 0,
    );

    expect(quality.isAcceptable, isFalse);
    expect(
      quality.issues,
      containsAll([
        TemplateQualityIssue.segmentTooShort,
        TemplateQualityIssue.validFramesTooFew,
        TemplateQualityIssue.validRatioTooLow,
        TemplateQualityIssue.bodyConfidenceTooLow,
        TemplateQualityIssue.normalizationFailed,
        TemplateQualityIssue.movementTooLow,
        TemplateQualityIssue.noCompleteMovement,
      ]),
    );
    expect(quality.messages, everyElement(isNotEmpty));
  });

  test('quality summary survives JSON round-trip', () {
    final quality = TemplateQualityValidator.evaluate(
      segmentDuration: const Duration(milliseconds: 300),
      attemptedFrameCount: 2,
      validFrameCount: 0,
      normalizedFrameCount: 0,
      movementIntensity: 0,
      detectedRepetitions: 0,
    );

    expect(TemplateQualitySummary.fromJson(quality.toJson()).toJson(),
        quality.toJson());
  });
}
