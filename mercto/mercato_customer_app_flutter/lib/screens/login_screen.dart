import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mercato/core/api_client.dart';
import 'package:mercato/core/app_theme.dart';
import 'package:mercato/core/mercato_logo.dart';
import 'package:mercato/providers/auth_provider.dart';
import 'package:mercato/screens/main_shell.dart';
import 'package:mercato/screens/register_screen.dart';

const _red = AppColors.jade, _gray = AppColors.ash;

String _tx(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

String _asciiDigits(String value) =>
    String.fromCharCodes(value.runes.map((rune) {
      if (rune >= 0x0660 && rune <= 0x0669) return rune - 0x0660 + 0x30;
      if (rune >= 0x06F0 && rune <= 0x06F9) return rune - 0x06F0 + 0x30;
      return rune;
    })).replaceAll(RegExp(r'\D'), '');

final _phoneDigitFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'[0-9٠-٩۰-۹]'),
);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController(), _password = TextEditingController();
  final _confirm = TextEditingController(), _otp = TextEditingController();
  bool _reset = false, _visible = false, _confirmVisible = false, _busy = false;
  String? _error;
  String? _developmentCode;
  String get _number => '+218${_asciiDigits(_phone.text)}';

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      if (_reset)
        await auth.resetPassword(
            _number, _asciiDigits(_otp.text), _password.text);
      await auth.loginWithPassword(_number, _password.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = _tx(
            context,
            "حدث خطأ غير متوقع. حاول مرة أخرى.",
            "Something went wrong. Please try again."));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    if (_asciiDigits(_phone.text).length != 9) {
      setState(() => _error = _tx(context, "أدخل رقم هاتف ليبي صحيحًا.",
          "Enter a valid Libyan phone number."));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await context.read<AuthProvider>().requestOtp(_number);
      if (mounted) {
        setState(() {
          _reset = true;
          _developmentCode = code;
          if (code != null) _otp.text = code;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = _tx(
            context,
            "حدث خطأ غير متوقع. حاول مرة أخرى.",
            "Something went wrong. Please try again."));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: Localizations.localeOf(context).languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: SafeArea(
              child: LayoutBuilder(builder: (context, box) {
                final compact = box.maxHeight < 760;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight - 30),
                    child: Column(children: [
                      Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: IconButton(
                              tooltip: _tx(context, "رجوع", "Back"),
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.chevron_right_rounded,
                                  size: 34))),
                      SizedBox(height: compact ? 8 : 40),
                      const MercatoLogoMark(size: 104),
                      SizedBox(height: compact ? 28 : 72),
                      Text(
                          _reset
                              ? _tx(context, "إعادة تعيين كلمة المرور",
                                  "Reset password")
                              : _tx(context, "تسجيل الدخول", "Sign in"),
                          style: TextStyle(
                              fontSize: compact ? 30 : 36,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF222222))),
                      const SizedBox(height: 12),
                      Text(
                          _reset
                              ? _tx(
                                  context,
                                  "أدخل رمز التحقق ورقم هاتفك لتعيين كلمة مرور جديدة",
                                  "Enter the verification code and your phone number to reset your password")
                              : _tx(context, "أدخل رقم هاتفك للمتابعة",
                                  "Enter your phone number to continue"),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _gray, fontSize: 17)),
                      if (_developmentCode != null) ...[
                        const SizedBox(height: 8),
                        Text(_tx(context, "رمز التطوير:", "Development code:"),
                            style: const TextStyle(
                                color: _red, fontWeight: FontWeight.w700)),
                      ],
                      SizedBox(height: compact ? 34 : 78),
                      Form(
                          key: _form,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Field(
                                    controller: _phone,
                                    hint: _tx(
                                        context, "رقم الهاتف", "Phone number"),
                                    keyboard: TextInputType.phone,
                                    enabled: !_reset && !_busy,
                                    formatters: [
                                      _phoneDigitFormatter,
                                      LengthLimitingTextInputFormatter(9)
                                    ],
                                    leading: const _Prefix(),
                                    validator: (v) => _asciiDigits(v ?? '')
                                                .length !=
                                            9
                                        ? _tx(
                                            context,
                                            "يجب أن يتكون رقم الهاتف من 9 أرقام",
                                            "Phone number must contain 9 digits")
                                        : null),
                                const SizedBox(height: 18),
                                if (_reset) ...[
                                  _Field(
                                      controller: _otp,
                                      hint: _tx(context, "رمز التحقق",
                                          "Verification code"),
                                      keyboard: TextInputType.number,
                                      formatters: [
                                        _phoneDigitFormatter,
                                        LengthLimitingTextInputFormatter(6)
                                      ],
                                      validator: (v) => _asciiDigits(v ?? '')
                                                  .length !=
                                              6
                                          ? _tx(
                                              context,
                                              "يجب أن يتكون رمز التحقق من 6 أرقام",
                                              "Verification code must contain 6 digits")
                                          : null),
                                  const SizedBox(height: 18),
                                ],
                                _Field(
                                    controller: _password,
                                    hint: _reset
                                        ? _tx(
                                            context, "كلمة مرور جديدة", "New password")
                                        : _tx(
                                            context, "كلمة المرور", "Password"),
                                    obscure: !_visible,
                                    trailing: IconButton(
                                        tooltip: _visible
                                            ? _tx(
                                                context, 'إخفاء كلمة المرور', 'Hide password')
                                            : _tx(
                                                context, 'إظهار كلمة المرور', 'Show password'),
                                        icon: Icon(_visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                            color: const Color(0xFFDDDDDD)),
                                        onPressed: () => setState(
                                            () => _visible = !_visible)),
                                    validator: (v) => (v == null || v.length < 8)
                                        ? _tx(
                                            context,
                                            "يجب ألا تقل كلمة المرور عن 8 أحرف",
                                            "Password must be at least 8 characters")
                                        : null),
                                if (_reset) ...[
                                  const SizedBox(height: 18),
                                  _Field(
                                      controller: _confirm,
                                      hint: _tx(
                                          context, "تأكيد كلمة المرور", "Confirm password"),
                                      obscure: !_confirmVisible,
                                      trailing: IconButton(
                                          tooltip: _confirmVisible
                                              ? _tx(
                                                  context, 'إخفاء كلمة المرور', 'Hide password')
                                              : _tx(
                                                  context,
                                                  'إظهار كلمة المرور',
                                                  'Show password'),
                                          icon: Icon(_confirmVisible
                                              ? Icons.visibility_rounded
                                              : Icons.visibility_off_rounded),
                                          onPressed: () => setState(() =>
                                              _confirmVisible =
                                                  !_confirmVisible)),
                                      validator: (v) => v != _password.text
                                          ? _tx(
                                              context,
                                              "كلمتا المرور غير متطابقتين",
                                              "Passwords do not match")
                                          : null),
                                ],
                              ])),
                      if (!_reset)
                        Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton(
                                onPressed: _busy ? null : _forgot,
                                style: TextButton.styleFrom(
                                    foregroundColor: _red,
                                    padding: EdgeInsets.zero),
                                child: Text(
                                    _tx(context, "نسيت كلمة المرور؟",
                                        "Forgot password?"),
                                    style: TextStyle(fontSize: 15)))),
                      if (_error != null) ...[
                        const SizedBox(height: 6),
                        Text(_error!, style: const TextStyle(color: _red))
                      ],
                      SizedBox(height: compact ? 18 : 26),
                      SizedBox(
                          width: double.infinity,
                          height: 62,
                          child: ElevatedButton(
                              onPressed: _busy ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: _red,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24)),
                                  textStyle: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700)),
                              child: _busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : Text(_reset
                                      ? _tx(context, "إعادة تعيين كلمة المرور",
                                          "Reset password")
                                      : _tx(context, "تسجيل الدخول",
                                          "Sign in")))),
                      SizedBox(height: compact ? 54 : 100),
                      if (!_reset)
                        Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                  _tx(context, "ليس لديك حساب؟",
                                      "Do not have an account?"),
                                  style: TextStyle(color: _gray, fontSize: 16)),
                              TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const RegisterScreen())),
                                  style: TextButton.styleFrom(
                                      foregroundColor: _red,
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap),
                                  child: Text(
                                      _tx(context, "إنشاء حساب جديد",
                                          "Create an account"),
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600))),
                            ]),
                      const SizedBox(height: 34),
                      Wrap(alignment: WrapAlignment.center, children: [
                        Text(
                            _tx(context, "بالمتابعة، أنت توافق على",
                                "By continuing, you agree to the"),
                            style: TextStyle(color: _gray, fontSize: 14)),
                        Text(
                            _tx(context, "الشروط والأحكام",
                                "Terms and conditions"),
                            style: TextStyle(color: _red, fontSize: 14)),
                      ]),
                    ]),
                  ),
                );
              }),
            )),
      );
}

class _Field extends StatelessWidget {
  const _Field(
      {required this.controller,
      required this.hint,
      this.keyboard,
      this.formatters,
      this.validator,
      this.obscure = false,
      this.leading,
      this.trailing,
      this.enabled = true});
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? validator;
  final bool obscure, enabled;
  final Widget? leading, trailing;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      height: 64,
      child: TextFormField(
          controller: controller,
          keyboardType: keyboard,
          inputFormatters: formatters,
          enabled: enabled,
          textAlign: leading == null ? TextAlign.right : TextAlign.left,
          textDirection: leading == null ? null : TextDirection.ltr,
          obscureText: obscure,
          validator: validator,
          decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 19),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              prefixIcon: leading,
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 112, minHeight: 56),
              suffixIcon: trailing,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide:
                      const BorderSide(color: Color(0xFFAAAAAA), width: 1.25)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide:
                      const BorderSide(color: Color(0xFFAAAAAA), width: 1.25)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: _red, width: 1.6)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: _red, width: 1.25)),
              focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: _red, width: 1.6)))));
}

class _Prefix extends StatelessWidget {
  const _Prefix();
  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsetsDirectional.only(start: 14, end: 6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('🇱🇾', style: TextStyle(fontSize: 21)),
        SizedBox(width: 7),
        Directionality(
            textDirection: TextDirection.ltr,
            child: Text('\u200E+218',
                style: TextStyle(color: Color(0xFF333333), fontSize: 16)))
      ]));
}
