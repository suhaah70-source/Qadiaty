import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mercato_super_admin_dashboard/screens/login_screen.dart';

void main() {
  testWidgets('super admin login requests phone and password', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.text('رقم الهاتف'), findsOneWidget);
    expect(find.text('كلمة المرور'), findsOneWidget);
    expect(find.textContaining('+218'), findsOneWidget);
    expect(find.text('دخول المدير'), findsOneWidget);
  });
}
