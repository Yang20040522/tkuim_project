class ZegoCallConfig {
  const ZegoCallConfig._();

  static const int appId = 1984786592;
  static const String appSign = 'd9d3e90a5c207d1f4286c0b900c227aea717a60c123b579b95d0718380239093';

  static bool get isConfigured => appId > 0 && appSign.trim().isNotEmpty;
}

// Embedded credentials are intentionally limited to this student demo/testing
// project. Production should use a server-issued ZEGO token instead.
