import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/phone_utils.dart';
import '../providers/auth_provider.dart';
import 'shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false, _passwordVisible = false, _rememberMe = false;
  String? _error;

  Future<void> _submit() async {
    if (_phoneController.text.trim().length != 9 ||
        _passwordController.text.isEmpty) {
      setState(() => _error = 'أدخل رقم هاتف ليبيًا من 9 أرقام وكلمة المرور.');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final phone = normalizeLibyanPhone(_phoneController.text);
      await context
          .read<AuthProvider>()
          .login(phone, _passwordController.text, rememberMe: _rememberMe);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ShellScreen()));
    } on FormatException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } on NotSuperAdminException {
      if (mounted) {
        setState(() => _error = 'هذا الحساب غير مخوّل لإدارة النظام.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'تعذر تسجيل الدخول. تحقق من الرقم وكلمة المرور واتصال الإنترنت.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
              child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                        child: ConstrainedBox(
                            constraints: BoxConstraints(
                                minHeight: constraints.maxHeight - 36),
                            child: Center(
                                child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    const SizedBox(height: 28),
                                    ClipRRect(
                                        borderRadius: BorderRadius.circular(22),
                                        child: Image.asset(
                                            'assets/icon/icon.png',
                                            width: 96,
                                            height: 96,
                                            fit: BoxFit.cover)),
                                    const SizedBox(height: 16),
                                    Text('تسجيل الدخول',
                                        style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w800,
                                            color: colors.onSurface)),
                                    const SizedBox(height: 26),
                                    _buildForm(),
                                    const SizedBox(height: 28),
                                  ]),
                            ))),
                      ))),
        ));
  }

  Widget _fieldBox({required Widget child}) => Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant, width: 1.2),
          borderRadius: BorderRadius.circular(14)),
      child: child);

  Widget _buildForm() {
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _fieldBox(child: _libyaPhoneField()),
      const SizedBox(height: 14),
      _fieldBox(
          child: Row(children: [
        Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, end: 12),
            child: Icon(Icons.lock_rounded, color: colors.onSurfaceVariant)),
        Expanded(
            child: TextField(
                controller: _passwordController,
                obscureText: !_passwordVisible,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: TextStyle(color: colors.onSurface, fontSize: 17),
                decoration: const InputDecoration(
                    hintText: 'كلمة المرور',
                    border: InputBorder.none,
                    filled: false))),
        IconButton(
            tooltip:
                _passwordVisible ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور',
            onPressed: () =>
                setState(() => _passwordVisible = !_passwordVisible),
            icon: Icon(
                _passwordVisible
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: colors.onSurfaceVariant)),
      ])),
      const SizedBox(height: 8),
      Row(children: [
        Checkbox(
            value: _rememberMe,
            activeColor: const Color(0xFFE34949),
            onChanged: _loading
                ? null
                : (v) => setState(() => _rememberMe = v ?? false)),
        Text('تذكرني', style: TextStyle(color: colors.onSurface)),
        const Spacer(),
        TextButton(
            onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                      content: const Text(
                          'لإعادة تعيين كلمة المرور، تواصل مع مسؤول النظام.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('حسنًا'))
                      ],
                    )),
            child: const Text('هل نسيت كلمة المرور؟',
                style: TextStyle(color: Color(0xFFE34949)))),
      ]),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFCC3434), fontSize: 13))
      ],
      const SizedBox(height: 28),
      SizedBox(
          height: 62,
          child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE34949),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 21, fontWeight: FontWeight.w700)),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('دخول المدير'))),
    ]);
  }

  Widget _libyaPhoneField() {
    final colors = Theme.of(context).colorScheme;
    return Row(children: [
      Padding(
          padding: const EdgeInsetsDirectional.only(start: 14, end: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('🇱🇾', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 7),
            Directionality(
                textDirection: TextDirection.ltr,
                child: Text('\u200E+218',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                        fontSize: 16))),
          ])),
      Container(width: 1, height: 30, color: colors.outlineVariant),
      Expanded(
          child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹]')),
                LengthLimitingTextInputFormatter(9)
              ],
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                  hintText: 'رقم الهاتف',
                  border: InputBorder.none,
                  filled: false,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 20)))),
    ]);
  }
}
