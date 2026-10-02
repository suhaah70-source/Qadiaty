import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mercato/core/app_theme.dart';
import 'package:mercato/providers/auth_provider.dart';
import 'package:mercato/providers/cart_provider.dart';
import 'package:mercato/providers/theme_provider.dart';
import 'package:mercato/providers/language_provider.dart';
import 'package:mercato/providers/location_provider.dart';
import 'package:mercato/screens/splash_screen.dart';

void main() {
  runApp(const MercatoApp());
}

class MercatoApp extends StatelessWidget {
  const MercatoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, theme, language, _) => MaterialApp(
          title: language.locale.languageCode == 'ar' ? 'قضيتي' : 'Mercato',
          locale: language.locale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          debugShowCheckedModeBanner: false,
          theme: buildMercatoTheme(),
          darkTheme: buildMercatoTheme(brightness: Brightness.dark),
          themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
