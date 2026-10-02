import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mercato_tenant_dashboard/screens/login_screen.dart';

void main() {
  testWidgets('tenant dashboard requests phone and password', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.text('رقم الهاتف'), findsOneWidget);
    expect(find.text('كلمة المرور'), findsOneWidget);
    expect(find.textContaining('+218'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsNWidgets(2));
  });
}
