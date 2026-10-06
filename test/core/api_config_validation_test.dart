import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_body/core/api_config.dart';

void main() {
  test('API override preserves production default', () {
    const expected = String.fromEnvironment('API_BASE_URL',
        defaultValue: 'https://trianing-system-1.onrender.com');
    expect(ApiConfig.baseUrl, expected);
  });
  test('cleartext research requires explicit loopback-only validation build',
      () {
    expect(
        ApiConfig.allowsResearchTransport(Uri.parse('https://example.invalid')),
        isTrue);
    for (final url in [
      'http://example.invalid:18083',
      'http://192.168.137.186:18083',
      'http://127.0.0.1:8080',
      'http://user@127.0.0.1:18083',
    ]) {
      expect(ApiConfig.allowsResearchTransport(Uri.parse(url)), isFalse);
    }
    expect(
        ApiConfig.allowsResearchTransport(
            Uri.parse('http://127.0.0.1:18083/api/ml-research/consent')),
        ApiConfig.localResearchValidation &&
            ApiConfig.baseUrl == 'http://127.0.0.1:18083');
  });
}
