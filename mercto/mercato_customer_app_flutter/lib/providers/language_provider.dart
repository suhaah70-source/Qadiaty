import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mercato/core/api_client.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('ar');
  Locale get locale => _locale;

  LanguageProvider() {
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final code = preferences.getString('app_language') ?? 'ar';
    _locale = code == 'en' ? const Locale('en') : const Locale('ar');
    ApiClient.instance.setLanguageCode(_locale.languageCode);
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (code != 'ar' && code != 'en') return;
    _locale = Locale(code);
    ApiClient.instance.setLanguageCode(code);
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('app_language', code);
  }
}
