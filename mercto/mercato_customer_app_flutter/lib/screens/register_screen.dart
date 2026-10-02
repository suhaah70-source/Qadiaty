import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mercato/core/api_client.dart';
import 'package:mercato/core/app_theme.dart';
import 'package:mercato/core/mercato_logo.dart';
import 'package:mercato/providers/auth_provider.dart';
import 'package:mercato/screens/main_shell.dart';

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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _phone = TextEditingController();
  final _password = TextEditingController(), _confirm = TextEditingController();
  final _invite = TextEditingController(), _otp = TextEditingController();
  bool _inviteVisible = false,
      _passwordVisible = false,
      _confirmPasswordVisible = false,
      _terms = true,
      _otpSent = false,
      _busy = false;
  String? _error;
  String? _developmentCode;
  String get _number => '+218${_asciiDigits(_phone.text)}';

  Future<void> _submit() async {
    if (!_terms) {
      setState(() => _error = _tx(
          context,
          "يرجى الموافقة على الشروط والأحكام للمتابعة.",
          "Please accept the terms and conditions to continue."));
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      if (!_otpSent) {
        final code = await auth.requestOtp(_number);
        if (mounted) {
          setState(() {
            _otpSent = true;
            _developmentCode = code;
            if (code != null) _otp.text = code;
          });
        }
      } else {
        await auth.verifyOtp(_number, _asciiDigits(_otp.text),
            fullName: _name.text.trim(),
            password: _password.text,
            termsAccepted: true,
            inviteCode: _invite.text.trim());
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainShell()), (_) => false);
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
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    _invite.dispose();
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
                      SizedBox(height: compact ? 6 : 24),
                      const MercatoLogoMark(size: 104),
                      SizedBox(height: compact ? 20 : 44),
                      Text(
                          _otpSent
                              ? _tx(context, "تأكيد رقم الهاتف",
                                  "Verify phone number")
                              : _tx(
                                  context, "إنشاء حساب جديد", "Create account"),
                          style: TextStyle(
                              fontSize: compact ? 29 : 34,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF222222))),
                      const SizedBox(height: 10),
                      Text(
                          _otpSent
                              ? _tx(context, "أدخل رمز التحقق المرسل إلى هاتفك",
                                  "Enter the verification code sent to your phone")
                              : _tx(context, "أدخل بياناتك للتسجيل",
                                  "Enter your details to register"),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _gray, fontSize: 17)),
                      if (_developmentCode != null) ...[
                        const SizedBox(height: 8),
                        Text(
                            _tx(context, "رمز التحقق: $_developmentCode",
                                "Verification code: $_developmentCode"),
                            style: const TextStyle(
                                color: _red, fontWeight: FontWeight.w700)),
                      ],
                      SizedBox(height: compact ? 26 : 46),
                      Form(
                          key: _form,
                          child: Column(children: [
                            _Field(
                                controller: _name,
                                hint: _tx(context, "مثال: أحمد علي",
                                    "Example: Ahmed Ali"),
                                icon: Icons.person_rounded,
                                keyboard: TextInputType.name,
                                formatters: [
                                  LengthLimitingTextInputFormatter(120),
                                ],
                                enabled: !_otpSent && !_busy,
                                validator: (v) =>
                                    (v == null || v.trim().length < 2)
                                        ? _tx(context, "يرجى إدخال اسمك الكامل",
                                            "Enter your full name")
                                        : null),
                            const SizedBox(height: 16),
                            _Field(
                                controller: _phone,
                                hint:
                                    _tx(context, "رقم الهاتف", "Phone number"),
                                icon: Icons.person_rounded,
                                enabled: !_otpSent && !_busy,
                                keyboard: TextInputType.phone,
                                formatters: [
                                  _phoneDigitFormatter,
                                  LengthLimitingTextInputFormatter(9)
                                ],
                                leading: const _Prefix(),
                                validator: (v) =>
                                    _asciiDigits(v ?? '').length != 9
                                        ? _tx(
                                            context,
                                            "أدخل رقم هاتف ليبي صحيحًا",
                                            "Enter a valid Libyan phone number")
                                        : null),
                            const SizedBox(height: 16),
                            _Field(
                                controller: _password,
                                hint: _tx(context, "كلمة السر", "Password"),
                                icon: Icons.lock_rounded,
                                obscure: !_passwordVisible,
                                formatters: [
                                  LengthLimitingTextInputFormatter(128),
                                ],
                                trailing: IconButton(
                                  tooltip: _passwordVisible
                                      ? _tx(context, 'إخفاء كلمة المرور',
                                          'Hide password')
                                      : _tx(context, 'إظهار كلمة المرور',
                                          'Show password'),
                                  onPressed: () => setState(() =>
                                      _passwordVisible = !_passwordVisible),
                                  icon: Icon(_passwordVisible
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded),
                                ),
                                enabled: !_otpSent && !_busy,
                                validator: (v) => (v == null || v.length < 8)
                                    ? _tx(
                                        context,
                                        "يجب ألا تقل كلمة المرور عن 8 أحرف",
                                        "Password must be at least 8 characters")
                                    : null),
                            const SizedBox(height: 16),
                            _Field(
                                controller: _confirm,
                                hint: _tx(context, "تأكيد كلمة المرور",
                                    "Confirm password"),
                                icon: Icons.lock_rounded,
                                obscure: !_confirmPasswordVisible,
                                formatters: [
                                  LengthLimitingTextInputFormatter(128),
                                ],
                                trailing: IconButton(
                                  tooltip: _confirmPasswordVisible
                                      ? _tx(context, 'إخفاء كلمة المرور',
                                          'Hide password')
                                      : _tx(context, 'إظهار كلمة المرور',
                                          'Show password'),
                                  onPressed: () => setState(() =>
                                      _confirmPasswordVisible =
                                          !_confirmPasswordVisible),
                                  icon: Icon(_confirmPasswordVisible
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded),
                                ),
                                enabled: !_otpSent && !_busy,
                                validator: (v) => v != _password.text
                                    ? _tx(context, "كلمتا المرور غير متطابقتين",
                                        "Passwords do not match")
                                    : null),
                            if (_inviteVisible && !_otpSent) ...[
                              const SizedBox(height: 16),
                              _Field(
                                  controller: _invite,
                                  hint: _tx(context, "رمز الدعوة (اختياري)",
                                      "Invitation code (optional)"),
                                  icon: Icons.card_giftcard_rounded,
                                  enabled: !_busy),
                            ],
                            if (_otpSent) ...[
                              const SizedBox(height: 16),
                              _Field(
                                  controller: _otp,
                                  hint: _tx(context, "رمز التحقق",
                                      "Verification code"),
                                  icon: Icons.sms_rounded,
                                  keyboard: TextInputType.number,
                                  formatters: [
                                    _phoneDigitFormatter,
                                    LengthLimitingTextInputFormatter(6)
                                  ],
                                  validator: (v) =>
                                      _asciiDigits(v ?? '').length != 6
                                          ? _tx(context, "أدخل رمز تحقق صحيحًا",
                                              "Enter a valid verification code")
                                          : null),
                            ],
                          ])),
                      if (!_otpSent) ...[
                        const SizedBox(height: 12),
                        CheckboxListTile(
                            value: _inviteVisible,
                            onChanged: _busy
                                ? null
                                : (v) =>
                                    setState(() => _inviteVisible = v ?? false),
                            controlAffinity: ListTileControlAffinity.trailing,
                            contentPadding: EdgeInsets.zero,
                            activeColor: _red,
                            title: Text(
                                _tx(
                                    context,
                                    "لدي رمز دعوة؟ إذا لم يكن لديك، اتركه فارغًا",
                                    "Have an invitation code? Leave it empty if you don't have one"),
                                style: TextStyle(fontSize: 15))),
                        CheckboxListTile(
                            value: _terms,
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _terms = v ?? false),
                            controlAffinity: ListTileControlAffinity.trailing,
                            contentPadding: EdgeInsets.zero,
                            activeColor: _red,
                            title: Wrap(children: [
                              Text(
                                  _tx(context, "أنا أتفق مع كل",
                                      "I agree to all"),
                                  style: TextStyle(fontSize: 15)),
                              Text(
                                  _tx(context, "الشروط والأحكام",
                                      "Terms and conditions"),
                                  style: TextStyle(fontSize: 15, color: _red))
                            ])),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: const TextStyle(color: _red))
                      ],
                      SizedBox(height: compact ? 14 : 26),
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
                                  : Text(_otpSent
                                      ? _tx(context, "تأكيد الحساب",
                                          "Complete registration")
                                      : _tx(context, "إنشاء حساب جديد",
                                          "Create account")))),
                      SizedBox(height: compact ? 22 : 40),
                      if (!_otpSent)
                        Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                  _tx(context, "لديك حساب بالفعل؟",
                                      "Already have an account?"),
                                  style: TextStyle(color: _gray, fontSize: 16)),
                              TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: TextButton.styleFrom(
                                      foregroundColor: _red,
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap),
                                  child: Text(
                                      _tx(context, 'تسجيل الدخول', 'Sign in'),
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600))),
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
      required this.icon,
      this.enabled = true,
      this.keyboard,
      this.formatters,
      this.validator,
      this.obscure = false,
      this.leading,
      this.trailing});
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool enabled, obscure;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? validator;
  final Widget? leading;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 64,
      child: TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboard,
          inputFormatters: formatters,
          textAlign: leading == null ? TextAlign.right : TextAlign.left,
          textDirection:
              leading != null ? TextDirection.ltr : TextDirection.rtl,
          obscureText: obscure,
          validator: validator,
          decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 18),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              prefixIcon: leading ?? Icon(icon, color: _gray, size: 21),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 54, minHeight: 56),
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
      padding: EdgeInsetsDirectional.only(start: 12, end: 4),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('🇱🇾', style: TextStyle(fontSize: 20)),
        SizedBox(width: 6),
        Directionality(
            textDirection: TextDirection.ltr,
            child: Text('\u200E+218',
                style: TextStyle(fontSize: 15, color: Color(0xFF333333))))
      ]));
}
