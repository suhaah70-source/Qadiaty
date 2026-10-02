import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mercato/core/constants.dart';

class ApiException implements Exception {
  final int statusCode;
  final String rawMessage;
  ApiException(this.statusCode, this.rawMessage);
  String get message => ApiClient.instance.localizeError(statusCode, rawMessage);
  @override
  String toString() => message;
}

/// عميل HTTP بسيط للتعامل مع الـ Backend.
class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();
  String? _accessToken;
  String? _refreshToken;
  String _languageCode = 'ar';

  void setLanguageCode(String code) {
    if (code == 'ar' || code == 'en') _languageCode = code;
  }

  String localizeError(int statusCode, String message) {
    const translations = <String, (String, String)>{
      'بيانات الدخول غير صالحة': ('بيانات الدخول غير صالحة', 'Invalid sign-in details'),
      'بيانات الدخول غير صحيحة': ('بيانات الدخول غير صحيحة', 'Incorrect sign-in details'),
      'رمز التحديث غير صالح': ('رمز التحديث غير صالح', 'The refresh token is invalid'),
      'صلاحيات مدير المنصة مطلوبة': ('يلزم امتلاك صلاحيات مدير المنصة', 'Platform administrator access is required'),
      'غير موجود': ('غير موجود', 'Not found'),
      'المتجر غير نشط حاليا': ('المتجر غير نشط حاليًا', 'This store is currently inactive'),
      'صلاحيات غير كافية': ('صلاحيات غير كافية', 'You do not have sufficient permissions'),
      'المتجر غير متاح': ('المتجر غير متاح', 'The store is unavailable'),
      'المنتج غير متاح': ('المنتج غير متاح', 'The product is unavailable'),
      'الكمية المطلوبة أكبر من المتوفر في المخزون': ('الكمية المطلوبة أكبر من المتوفر في المخزون', 'The requested quantity exceeds available stock'),
      'السلة فارغة': ('السلة فارغة', 'Your cart is empty'),
      'أحد المنتجات لم يعد متاحا': ('أحد المنتجات لم يعد متاحًا', 'One of the products is no longer available'),
      'البريد الإلكتروني مستخدم مسبقا': ('البريد الإلكتروني مستخدم مسبقًا', 'This email address is already in use'),
      'هذا الحساب موقوف': ('هذا الحساب موقوف', 'This account has been suspended'),
      'المتجر غير موجود أو غير نشط': ('المتجر غير موجود أو غير نشط', 'The store was not found or is inactive'),
      'الباقة غير موجودة': ('الباقة غير موجودة', 'The plan was not found'),
      'بريد المالك مستخدم مسبقا': ('بريد المالك مستخدم مسبقًا', 'The owner email address is already in use'),
      'الرابط مستخدم مسبقا داخل هذا المتجر': ('الرابط مستخدم مسبقًا داخل هذا المتجر', 'This link is already in use in this store'),
      'رمز المنتج (SKU) مستخدم مسبقا في هذا المتجر': ('رمز المنتج مستخدم مسبقًا في هذا المتجر', 'This product SKU is already in use in this store'),
      'لا يمكن دعوة مالك إضافي بهذه الطريقة': ('لا يمكن دعوة مالك إضافي بهذه الطريقة', 'You cannot invite another owner this way'),
      'لا يمكن إزالة مالك المتجر': ('لا يمكن إزالة مالك المتجر', 'The store owner cannot be removed'),
      'نوع الملف غير مسموح. الأنواع المسموحة: JPEG, PNG, WEBP': ('نوع الملف غير مسموح. الأنواع المسموحة: JPEG وPNG وWEBP', 'This file type is not allowed. Use JPEG, PNG, or WEBP'),
      'طريقة HTTP غير مدعومة': ('طريقة HTTP غير مدعومة', 'This HTTP method is not supported'),
      'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجددًا': ('انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجددًا', 'Your session expired. Please sign in again'),
      'Invalid phone number or password': ('رقم الهاتف أو كلمة المرور غير صحيحة', 'Invalid phone number or password'),
      'Password is required for registration': ('كلمة المرور مطلوبة لإنشاء الحساب', 'Password is required for registration'),
      'Terms acceptance is required': ('يجب الموافقة على الشروط والأحكام', 'Terms acceptance is required'),
      'انتظر قليلًا قبل طلب رمز جديد': ('انتظر قليلًا قبل طلب رمز جديد', 'Please wait before requesting another code'),
      'مزود رسائل SMS غير مربوط بعد': ('خدمة الرسائل النصية غير مفعّلة بعد', 'SMS messaging is not configured yet'),
      'اطلب رمز تحقق جديدًا': ('اطلب رمز تحقق جديدًا', 'Request a new verification code'),
      'انتهت صلاحية الرمز، اطلب رمزًا جديدًا': ('انتهت صلاحية الرمز، اطلب رمزًا جديدًا', 'The code expired. Request a new one'),
      'رمز التحقق غير صحيح': ('رمز التحقق غير صحيح', 'The verification code is incorrect'),
      'أدخل اسمك لإكمال إنشاء الحساب': ('أدخل اسمك لإكمال إنشاء الحساب', 'Enter your name to finish creating your account'),
      'Request a new verification code': ('اطلب رمز تحقق جديدًا', 'Request a new verification code'),
      'Verification code expired': ('انتهت صلاحية الرمز، اطلب رمزًا جديدًا', 'The verification code expired'),
      'Invalid verification code': ('رمز التحقق غير صحيح', 'The verification code is incorrect'),
      'Account not found': ('الحساب غير موجود', 'Account not found'),
      'Password updated': ('تم تحديث كلمة المرور', 'Password updated'),
    };
    if (message == 'CONNECTION_ERROR') {
      return _languageCode == 'ar'
          ? 'تعذر الاتصال بالخادم. تأكد من تشغيل الخادم واتصال الجهاز بالشبكة.'
          : 'Could not connect to the server. Check that it is running and your device is connected.';
    }
    var pair = translations[message];
    pair ??= translations.values.cast<(String, String)?>().firstWhere(
          (candidate) => candidate?.$2 == message,
          orElse: () => null,
        );
    if (pair != null) return _languageCode == 'ar' ? pair.$1 : pair.$2;
    if (!RegExp(r'[\u0600-\u06FF]').hasMatch(message)) return message;
    if (_languageCode == 'ar') return message;
    switch (statusCode) {
      case 400:
      case 422:
        return 'The submitted information is invalid. Please check and try again.';
      case 401:
        return 'Please check your sign-in details and try again.';
      case 403:
        return 'You do not have permission to perform this action.';
      case 404:
        return 'The requested item could not be found.';
      case 409:
        return 'This information is already in use.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
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
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  Map<String, String> _headers({bool auth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (auth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }
  Future<bool> _tryRefresh() async {
    if (_refreshToken == null) return false;
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/auth/refresh'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'refresh_token': _refreshToken,
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      await _saveTokens(
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
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
        return data['detail'].toString();
      }
    } catch (_) {
      // لو الرد مش JSON، نستعملوا رسالة الخطأ العادية.
    }
    return 'حدث خطأ غير متوقع (${res.statusCode})';
  }

  // ============================================================
  // POST عادي — يستعمل JSON
  // ============================================================
  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
    bool isRetry = false,
  }) async {
    final uri = Uri.parse('$kApiBaseUrl$path');
    http.Response res;
    try {
      switch (method) {
        case 'GET':
          res = await http.get(uri, headers: _headers(auth: auth));
          break;
        case 'POST':
          res = await http.post(
            uri,
            headers: _headers(auth: auth),
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PATCH':
          res = await http.patch(
            uri,
            headers: _headers(auth: auth),
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'DELETE':
          res = await http.delete(uri, headers: _headers(auth: auth));
          break;
        default:
          throw ApiException(0, 'طريقة HTTP غير مدعومة');
      }
    } on http.ClientException {
      throw ApiException(0, 'CONNECTION_ERROR');
    }
    // لو التوكن انتهت صلاحيته، نحاولوا نجددوه مرة وحدة.
    if (res.statusCode == 401 && auth && !isRetry) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _request(
          method,
          path,
          body: body,
          auth: auth,
          isRetry: true,
        );
      }
      await clearTokens();
      throw ApiException(
        401,
        'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجددًا',
      );
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return _decode(res);
    }
    throw ApiException(
      res.statusCode,
      _extractErrorMessage(res),
    );
  }
  // ============================================================
  // POST FORM
  // ============================================================
  // هذي زدناها مخصوص للـ Login.
  //
  // الـ Backend متاعنا في /auth/login يبي:
  //
  // email=...
  // password=...
  //
  // مش JSON.
  //
  // لذلك نستعملوا application/x-www-form-urlencoded.
  // ============================================================
  Future<dynamic> postForm(
    String path, {
    required Map<String, String> fields,
    bool auth = false,
  }) async {
    final uri = Uri.parse('$kApiBaseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded',
    };
    if (auth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    final res = await http.post(
      uri,
      headers: headers,
      body: fields,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return _decode(res);
    }
    throw ApiException(
      res.statusCode,
      _extractErrorMessage(res),
    );
  }
  Future<dynamic> get(
    String path, {
    bool auth = true,
  }) =>
      _request(
        'GET',
        path,
        auth: auth,
      );
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) =>
      _request(
        'POST',
        path,
        body: body,
        auth: auth,
      );
  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) =>
      _request(
        'PATCH',
        path,
        body: body,
        auth: auth,
      );
  Future<dynamic> delete(
    String path, {
    bool auth = true,
  }) =>
      _request(
        'DELETE',
        path,
        auth: auth,
      );
  /// نخزنوا التوكنات بعد ما الـ Login ينجح.
  Future<void> setTokensAfterLogin(
    String access,
    String refresh,
  ) =>
      _saveTokens(
        access,
        refresh,
      );
}
