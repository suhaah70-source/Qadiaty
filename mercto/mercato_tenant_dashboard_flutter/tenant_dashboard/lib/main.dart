import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/app_theme.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  runApp(const TenantDashboardApp());
}

class TenantDashboardApp extends StatelessWidget {
  const TenantDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: MaterialApp(
        title: 'قضيتي - لوحة التاجر',
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        debugShowCheckedModeBanner: false,
        theme: buildMercatoTheme(),
        darkTheme: buildMercatoTheme(brightness: Brightness.dark),
        themeMode: ThemeMode.system,
        home: const _Bootstrap(),
      ),
    );
  }
}

/// ����� �� ���� ���� ������ (����� �����) ��� ����� ������ ������ —
/// ���� ���� ���� ������ ��� ��� �����.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  @override
  void initState() {
    super.initState();
    context.read<AuthProvider>().bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.initialized) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            backgroundColor: AppColors.ink,
            body: Center(
                child: CircularProgressIndicator(color: AppColors.brass))),
      );
    }
    if (auth.isAuthenticated && auth.tenantId != null) {
      return const ShellScreen();
    }
    return const LoginScreen();
  }
}
