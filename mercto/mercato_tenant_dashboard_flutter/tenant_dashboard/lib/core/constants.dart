import 'package:flutter/foundation.dart';

/// ����� ��� Backend �������. ����� ��� ����� ������ (--dart-define=API_BASE_URL=...)
/// �� ������ ��� ����� ������� ������.
const String _configuredApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue:
      kIsWeb ? 'http://localhost:8001/api/v1' : 'http://10.0.2.2:8001/api/v1',
);

final String kApiBaseUrl = _normalizeApiBaseUrl(_configuredApiBaseUrl);

String _normalizeApiBaseUrl(String value) {
  var baseUrl = value.trim();
  while (baseUrl.endsWith('/')) {
    baseUrl = baseUrl.substring(0, baseUrl.length - 1);
  }
  return baseUrl.endsWith('/api/v1') ? baseUrl : '$baseUrl/api/v1';
}
