import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mercato/screens/login_screen.dart';
import 'package:mercato/screens/register_screen.dart';
import 'package:mercato/screens/welcome_screen.dart';
import 'package:mercato/providers/auth_provider.dart';
import 'package:mercato/providers/cart_provider.dart';
import 'package:mercato/providers/language_provider.dart';

void main() {
  testWidgets('login form has phone and password fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('registration form has required fields and consent controls',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    expect(find.byType(TextFormField), findsNWidgets(4));
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('welcome screen opens the customer shell for guest access',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: const MaterialApp(home: WelcomeScreen()),
      ),
    );
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.shopping_cart_rounded), findsOneWidget);
  });
}
