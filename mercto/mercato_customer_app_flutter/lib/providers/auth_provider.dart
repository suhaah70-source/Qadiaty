import 'package:flutter/foundation.dart';
import 'package:mercato/core/api_client.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _initialized = false;
  String? _userName;
  String? _phone;
  String? _role;
  double _loyaltyPoints = 0;
  double _walletBalance = 0;
  int _availableRewards = 0;

  bool get isAuthenticated => _isAuthenticated;
  bool get initialized => _initialized;
  String? get userName => _userName;
  String? get phone => _phone;
  String? get role => _role;
  double get loyaltyPoints => _loyaltyPoints;
  double get walletBalance => _walletBalance;
  int get availableRewards => _availableRewards;

  void _readProfile(Map<String, dynamic> user) {
    _userName = user['full_name'] as String?;
    _phone = user['phone'] as String?;
    _role = user['role'] as String?;
    _loyaltyPoints = (user['loyalty_points'] as num?)?.toDouble() ?? 0;
    _walletBalance = (user['wallet_balance'] as num?)?.toDouble() ?? 0;
    _availableRewards = (user['available_rewards'] as num?)?.toInt() ?? 0;
  }

  Future<void> bootstrap() async {
    await ApiClient.instance.loadTokens();
    _isAuthenticated = ApiClient.instance.isAuthenticated;
    if (_isAuthenticated) {
      try {
        final user = await ApiClient.instance.get('/auth/me')
            as Map<String, dynamic>;
        _readProfile(user);
      } on ApiException catch (error) {
        if (error.statusCode == 401) {
          await ApiClient.instance.clearTokens();
          _isAuthenticated = false;
        }
      } catch (_) {
        // Keep the local session while the API is temporarily unreachable.
      }
    }
    _initialized = true;
    notifyListeners();
  }

  Future<String?> requestOtp(String phone) async {
    final response = await ApiClient.instance.post(
      '/auth/request-otp',
      body: {'phone': phone.trim()},
      auth: false,
    ) as Map<String, dynamic>;
    return response['debug_code'] as String?;
  }

  Future<void> loginWithPassword(String phone, String password) async {
    final result = await ApiClient.instance.post(
      '/auth/login',
      body: {'phone': phone.trim(), 'password': password},
      auth: false,
    ) as Map<String, dynamic>;
    await _acceptAuthResult(result);
  }

  Future<void> resetPassword(
      String phone, String code, String newPassword) async {
    await ApiClient.instance.post(
      '/auth/reset-password',
      body: {
        'phone': phone.trim(),
        'code': code.trim(),
        'new_password': newPassword,
      },
      auth: false,
    );
  }

  Future<void> verifyOtp(
    String phone,
    String code, {
    String? fullName,
    String? city,
    String? password,
    bool termsAccepted = false,
    String? inviteCode,
  }) async {
    final result = await ApiClient.instance.post(
      '/auth/verify-otp',
      body: {
        'phone': phone.trim(),
        'code': code.trim(),
        if (password != null) 'password': password,
        if (termsAccepted) 'terms_accepted': true,
        if (inviteCode != null && inviteCode.trim().isNotEmpty)
          'invite_code': inviteCode.trim(),
        if (fullName != null && fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      },
      auth: false,
    ) as Map<String, dynamic>;
    await _acceptAuthResult(result);
  }

  Future<void> _acceptAuthResult(Map<String, dynamic> result) async {
    await ApiClient.instance.setTokensAfterLogin(
      result['access_token'] as String,
      result['refresh_token'] as String,
    );
    final user = result['user'] as Map<String, dynamic>?;
    _isAuthenticated = true;
    if (user != null) _readProfile(user);
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    final user = await ApiClient.instance.get('/auth/me')
        as Map<String, dynamic>;
    _readProfile(user);
    notifyListeners();
  }

  Future<void> redeemReward() async {
    final user = await ApiClient.instance.post('/loyalty/redeem')
        as Map<String, dynamic>;
    _readProfile(user);
    notifyListeners();
  }

  Future<void> logout() async {
    await ApiClient.instance.clearTokens();
    _isAuthenticated = false;
    _userName = null;
    _phone = null;
    _role = null;
    _loyaltyPoints = 0;
    _walletBalance = 0;
    _availableRewards = 0;
    notifyListeners();
  }
}
