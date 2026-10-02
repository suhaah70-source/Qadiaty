import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

/// ������� ����� ������ ��� API� ���� ����� ������ ������� �� ����.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// ���� HTTP ���� ���� ���� ������ �������ǡ ������ ��� ����� ���
/// ������ �������� (401) ��� ����� �������� — ��� ���� ����� ������
/// ����� ���� ������ ���� ������ ��� ����� ������ ��� ������.
class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  String? _accessToken;
  String? _refreshToken;
  bool _persistTokens = true;

  Future<void> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
  }

  bool get isAuthenticated => _accessToken != null;

  Future<void> _saveTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    if (_persistTokens) {
      await prefs.setString('access_token', access);
      await prefs.setString('refresh_token', refresh);
    } else {
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
    }
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  Map<String, String> _headers({bool auth = true}) {
    final headers = {'Content-Type': 'application/json'};
    if (auth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  Future<bool> _tryRefresh() async {
    if (_refreshToken == null) return false;
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': _refreshToken}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      await _saveTokens(
          data['access_token'] as String, data['refresh_token'] as String);
      return true;
    }
    return false;
  }

  dynamic _decode(http.Response res) {
    if (res.body.isEmpty) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  String _extractErrorMessage(http.Response res) {
    try {
      final data = _decode(res);
      if (data is Map<String, dynamic> && data['detail'] != null) {
        final message = data['detail'].toString();
        const translations = {
          'Invalid phone number or password':
              'رقم الهاتف أو كلمة المرور غير صحيحة.',
          'Invalid credentials': 'بيانات تسجيل الدخول غير صحيحة.',
          'Not authorized': 'ليس لديك صلاحية الدخول إلى هذه الصفحة.',
        };
        return translations[message] ?? message;
      }
    } catch (_) {
      // ����� ������� ����� ��������
    }
    return 'تعذر الاتصال بالخادم \(رمز ${res.statusCode}).';
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    bool isRetry = false,
  }) async {
    final uri = Uri.parse('$kApiBaseUrl$path');
    http.Response res;

    switch (method) {
      case 'GET':
        res = await http.get(uri, headers: _headers(auth: auth));
        break;
      case 'POST':
        res = await http.post(uri,
            headers: _headers(auth: auth),
            body: body != null ? jsonEncode(body) : null);
        break;
      case 'PATCH':
        res = await http.patch(uri,
            headers: _headers(auth: auth),
            body: body != null ? jsonEncode(body) : null);
        break;
      case 'DELETE':
        res = await http.delete(uri, headers: _headers(auth: auth));
        break;
      default:
        throw ApiException(0, 'طريقة الاتصال غير مدعومة.');
    }

    if (res.statusCode == 401 && auth && !isRetry) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _request(method, path, body: body, auth: auth, isRetry: true);
      }
      await clearTokens();
      throw ApiException(401, 'انتهت صلاحية الجلسة. سجّل الدخول من جديد.');
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return _decode(res);
    }

    throw ApiException(res.statusCode, _extractErrorMessage(res));
  }

  Future<dynamic> get(String path, {bool auth = true}) =>
      _request('GET', path, auth: auth);
  Future<dynamic> post(String path,
          {Map<String, dynamic>? body, bool auth = true}) =>
      _request('POST', path, body: body, auth: auth);
  Future<dynamic> patch(String path,
          {Map<String, dynamic>? body, bool auth = true}) =>
      _request('PATCH', path, body: body, auth: auth);
  Future<dynamic> delete(String path, {bool auth = true}) =>
      _request('DELETE', path, auth: auth);

  /// ������� ��� �� AuthProvider ��� ���� ����� ������.
  Future<void> setTokensAfterLogin(String access, String refresh,
      {bool rememberMe = true}) async {
    _persistTokens = rememberMe;
    await _saveTokens(access, refresh);
  }
}
