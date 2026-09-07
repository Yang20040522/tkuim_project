enum TemplateQualityIssue {
  segmentTooShort,
  attemptedFramesTooFew,
  validFramesTooFew,
  validRatioTooLow,
  bodyConfidenceTooLow,
  normalizationFailed,
  movementTooLow,
  noCompleteMovement,
}

extension TemplateQualityIssueMessage on TemplateQualityIssue {
  String get message => switch (this) {
        TemplateQualityIssue.segmentTooShort => '選取片段太短，請選擇一次完整示範。',
        TemplateQualityIssue.attemptedFramesTooFew => '選取片段可分析的影格太少。',
        TemplateQualityIssue.validFramesTooFew => '此片段可用骨架幀數不足，請重新選擇示範區段。',
        TemplateQualityIssue.validRatioTooLow => '此片段長時間未偵測到完整骨架。',
        TemplateQualityIssue.bodyConfidenceTooLow => '此片段的關鍵身體關節可信度不足。',
        TemplateQualityIssue.normalizationFailed => '骨架尺度不穩定，無法建立可靠的正規化模板。',
        TemplateQualityIssue.movementTooLow => '此片段動作量太低，請選擇完整動作區段。',
        TemplateQualityIssue.noCompleteMovement => '此片段未偵測到足夠完整的動作，無法建立標準模板。',
      };
}

class TemplateQualitySummary {
  const TemplateQualitySummary({
    required this.attemptedFrameCount,
    required this.validFrameCount,
    required this.normalizedFrameCount,
    required this.validRatio,
    required this.normalizationRatio,
    required this.averageConfidence,
    required this.movementIntensity,
    required this.detectedRepetitions,
    required this.issues,
  });

  final int attemptedFrameCount;
  final int validFrameCount;
  final int normalizedFrameCount;
  final double validRatio;
  final double normalizationRatio;
  final double? averageConfidence;
  final double movementIntensity;
  final int detectedRepetitions;
  final List<TemplateQualityIssue> issues;

  bool get isAcceptable => issues.isEmpty;
  List<String> get messages => issues.map((issue) => issue.message).toList();

  Map<String, dynamic> toJson() => {
        'isAcceptable': isAcceptable,
        'attemptedFrameCount': attemptedFrameCount,
        'validFrameCount': validFrameCount,
        'normalizedFrameCount': normalizedFrameCount,
        'validRatio': validRatio,
        'normalizationRatio': normalizationRatio,
        'averageConfidence': averageConfidence,
        'movementIntensity': movementIntensity,
        'detectedRepetitions': detectedRepetitions,
        'issues': issues.map((issue) => issue.name).toList(),
      };

  factory TemplateQualitySummary.fromJson(Map<String, dynamic> json) {
    final rawIssues = json['issues'] as List<dynamic>? ?? const [];
    return TemplateQualitySummary(
      attemptedFrameCount: (json['attemptedFrameCount'] as num?)?.toInt() ?? 0,
      validFrameCount: (json['validFrameCount'] as num?)?.toInt() ?? 0,
      normalizedFrameCount:
          (json['normalizedFrameCount'] as num?)?.toInt() ?? 0,
      validRatio: (json['validRatio'] as num?)?.toDouble() ?? 0,
      normalizationRatio: (json['normalizationRatio'] as num?)?.toDouble() ?? 0,
      averageConfidence: (json['averageConfidence'] as num?)?.toDouble(),
      movementIntensity: (json['movementIntensity'] as num?)?.toDouble() ?? 0,
      detectedRepetitions: (json['detectedRepetitions'] as num?)?.toInt() ?? 0,
      issues: rawIssues
          .map((raw) => TemplateQualityIssue.values.where(
                (issue) => issue.name == raw.toString(),
              ))
          .where((matches) => matches.isNotEmpty)
          .map((matches) => matches.first)
          .toList(),
    );
  }
}

class TemplateQualityValidator {
  const TemplateQualityValidator._();

  static const Duration minimumDuration = Duration(milliseconds: 800);
  static const int minimumAttemptedFrames = 4;
  static const int minimumValidFrames = 3;
  static const double minimumValidRatio = 0.5;
  static const double minimumNormalizationRatio = 0.5;
  static const double minimumBodyConfidence = 0.3;
  static const double minimumMovementIntensity = 0.01;

  static TemplateQualitySummary evaluate({
    required Duration segmentDuration,
    required int attemptedFrameCount,
    required int validFrameCount,
    required int normalizedFrameCount,
    required double movementIntensity,
    required int detectedRepetitions,
    double? averageBodyConfidence,
  }) {
    final validRatio =
        attemptedFrameCount == 0 ? 0.0 : validFrameCount / attemptedFrameCount;
    final normalizationRatio =
        validFrameCount == 0 ? 0.0 : normalizedFrameCount / validFrameCount;
    final issues = <TemplateQualityIssue>[];

    if (segmentDuration < minimumDuration) {
      issues.add(TemplateQualityIssue.segmentTooShort);
    }
    if (attemptedFrameCount < minimumAttemptedFrames) {
      issues.add(TemplateQualityIssue.attemptedFramesTooFew);
    }
    if (validFrameCount < minimumValidFrames) {
      issues.add(TemplateQualityIssue.validFramesTooFew);
    }
    if (validRatio < minimumValidRatio) {
      issues.add(TemplateQualityIssue.validRatioTooLow);
    }
    if (averageBodyConfidence != null &&
        averageBodyConfidence < minimumBodyConfidence) {
      issues.add(TemplateQualityIssue.bodyConfidenceTooLow);
    }
    if (normalizedFrameCount < minimumValidFrames ||
        normalizationRatio < minimumNormalizationRatio) {
      issues.add(TemplateQualityIssue.normalizationFailed);
    }
    if (movementIntensity < minimumMovementIntensity) {
      issues.add(TemplateQualityIssue.movementTooLow);
    }
    if (detectedRepetitions < 1) {
      issues.add(TemplateQualityIssue.noCompleteMovement);
    }

    return TemplateQualitySummary(
      attemptedFrameCount: attemptedFrameCount,
      validFrameCount: validFrameCount,
      normalizedFrameCount: normalizedFrameCount,
      validRatio: validRatio,
      normalizationRatio: normalizationRatio,
      averageConfidence: averageBodyConfidence,
      movementIntensity: movementIntensity,
      detectedRepetitions: detectedRepetitions,
      issues: List.unmodifiable(issues),
    );
  }
}
