import 'package:flutter/foundation.dart';
import '../core/api_client.dart';

/// ����� �� ������ ����� ���� ���� (Super Admin) ��� ������ ��� ������
/// ������� ���� ����� �������� (/tenants). �� ���� ��� ���� 403 —
/// ��� ������ ������� �� AuthContext ����� React.
class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _initialized = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get initialized => _initialized;

  Future<void> bootstrap() async {
    await ApiClient.instance.loadTokens();
    _isAuthenticated = ApiClient.instance.isAuthenticated;
    _initialized = true;
    notifyListeners();
  }

  Future<void> login(String phone, String password,
      {bool rememberMe = true}) async {
    final data = await ApiClient.instance.post(
      '/auth/login',
      body: {'phone': phone, 'password': password},
      auth: false,
    ) as Map<String, dynamic>;
    await ApiClient.instance.setTokensAfterLogin(
      data['access_token'] as String,
      data['refresh_token'] as String,
      rememberMe: rememberMe,
    );

    try {
      await ApiClient.instance.get('/admin/overview');
    } on ApiException catch (error) {
      await ApiClient.instance.clearTokens();
      if (error.statusCode == 403) throw NotSuperAdminException();
      rethrow;
    }
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await ApiClient.instance.clearTokens();
    _isAuthenticated = false;
    notifyListeners();
  }
}

class NotSuperAdminException implements Exception {}
