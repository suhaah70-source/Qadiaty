import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mercato/core/app_theme.dart';
import 'package:mercato/providers/theme_provider.dart';
import 'package:mercato/screens/login_screen.dart';
import 'package:mercato/screens/register_screen.dart';
import 'package:mercato/screens/main_shell.dart';

String _tx(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: Localizations.localeOf(context).languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(gradient: kInkGradient),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storefront_rounded,
                          color: Colors.white, size: 88),
                      const SizedBox(height: 18),
                      Text(
                          _tx(context, 'تسوّق من متاجرك المفضلة واكتشف منتجات جديدة بسهولة.', 'Shop your favorite stores and discover new products.'),
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen())),
                          child: Text(_tx(context, 'تسجيل الدخول', 'Sign in')),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white70)),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RegisterScreen())),
                          child: Text(_tx(context, 'إنشاء حساب', 'Create account')),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider(
                                create: (_) => ThemeProvider(),
                                child: const MainShell()),
                          ),
                        ),
                        child: Text(_tx(context, 'المتابعة كضيف', 'Continue as guest'),
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
