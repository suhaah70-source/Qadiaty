import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../models/models.dart';

/// ���� ���� ������ ������� ������ ����� (���� �� ���� ���� �� ����
/// ���ϡ ����� ������ ����� ���� — ��� ���� AuthContext �� ���� React).
class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _initialized = false;
  String? _tenantId;
  List<Tenant> _myTenants = [];

  bool get isAuthenticated => _isAuthenticated;
  bool get initialized => _initialized;
  String? get tenantId => _tenantId;
  List<Tenant> get myTenants => _myTenants;

  Tenant? get activeTenant {
    try {
      return _myTenants.firstWhere((t) => t.id == _tenantId);
    } catch (_) {
      return null;
    }
  }

  Future<void> bootstrap() async {
    await ApiClient.instance.loadTokens();
    final prefs = await SharedPreferences.getInstance();
    _tenantId = prefs.getString('tenant_id');
    _isAuthenticated = ApiClient.instance.isAuthenticated;
    _initialized = true;
    notifyListeners();
  }

  /// ���� ����� ������� �������� �������. ��� ��� ���� ���� ��ء ������
  /// ��������. ��� ���� �� ���ϡ ��� ������� ��� ���� ������ ������.
  Future<List<Tenant>> login(String phone, String password,
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
    _isAuthenticated = true;

    final tenantsRaw =
        await ApiClient.instance.get('/me/tenants') as List<dynamic>;
    _myTenants = tenantsRaw
        .map((e) => Tenant.fromJson(e as Map<String, dynamic>))
        .toList();
    if (_myTenants.length == 1) {
      await setTenantId(_myTenants.first.id);
    }
    notifyListeners();
    return _myTenants;
  }

  Future<void> setTenantId(String id) async {
    _tenantId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tenant_id', id);
    notifyListeners();
  }

  Future<void> logout() async {
    await ApiClient.instance.clearTokens();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tenant_id');
    _isAuthenticated = false;
    _tenantId = null;
    _myTenants = [];
    notifyListeners();
  }
}
