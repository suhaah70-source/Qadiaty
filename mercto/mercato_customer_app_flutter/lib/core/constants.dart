import 'package:flutter/foundation.dart';

const String _configuredApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue:
      kIsWeb ? 'http://localhost:8001/api/v1' : 'http://10.0.2.2:8001/api/v1',
);

// Accept both the server root and a versioned API URL. This prevents clients
// launched with `API_BASE_URL=http://localhost:8001` from requesting a
// non-existent `/auth/...` route and receiving a 404.
final String kApiBaseUrl = _normalizeApiBaseUrl(_configuredApiBaseUrl);

String _normalizeApiBaseUrl(String value) {
  var baseUrl = value.trim();
  while (baseUrl.endsWith('/')) {
    baseUrl = baseUrl.substring(0, baseUrl.length - 1);
  }
  return baseUrl.endsWith('/api/v1') ? baseUrl : '$baseUrl/api/v1';
}

/// عنوان المحاكي الافتراضي: Android يستخدم 10.0.2.2، والويب يستخدم localhost.
/// يمكن تحديد عنوان الخادم عبر وسيط البناء API_BASE_URL.
