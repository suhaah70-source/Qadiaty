import 'package:flutter/material.dart';
import 'package:mercato/core/api_client.dart';

String _tx(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

class StoreApplicationScreen extends StatefulWidget {
  const StoreApplicationScreen({super.key});

  @override
  State<StoreApplicationScreen> createState() => _StoreApplicationScreenState();
}

class _StoreApplicationScreenState extends State<StoreApplicationScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _description = TextEditingController();
  String _category = 'general';
  bool _busy = false;
  String? _message;
  bool _submitted = false;

  static const _categories = <String, (String, String)>{
    'clothing': ('ملابس', 'Clothing'),
    'shoes': ('أحذية', 'Shoes'),
    'pharmacy': ('صيدليات', 'Pharmacy'),
    'electronics': ('إلكترونيات', 'Electronics'),
    'home': ('المنزل', 'Home'),
    'beauty': ('الجمال والعناية', 'Beauty & care'),
    'grocery': ('مواد غذائية', 'Groceries'),
    'general': ('متجر عام', 'General store'),
  };

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ApiClient.instance.post('/stores/applications', body: {
        'name': _name.text.trim(),
        'city': _city.text.trim(),
        'description': _description.text.trim(),
        'store_category': _category,
      });
      if (mounted) {
        setState(() {
          _submitted = true;
          _message = _tx(context, 'تم إرسال طلبك بنجاح. سنراجعه ونتواصل معك.',
              'Your application was sent. We will review it and contact you.');
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message = _tx(
            context,
            'تعذر إرسال الطلب. حاول مرة أخرى.',
            'Could not submit the application. Please try again.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? value, {int min = 2}) =>
      (value ?? '').trim().length < min
          ? _tx(context, 'يرجى إدخال بيانات صحيحة',
              'Please enter valid information')
          : null;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: Localizations.localeOf(context).languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
              title:
                  Text(_tx(context, 'طلب فتح متجر', 'Apply to open a store'))),
          body: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !_submitted,
                  textAlign: TextAlign.right,
                  textDirection:
                      Localizations.localeOf(context).languageCode == 'ar'
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: _tx(context, 'اسم المتجر', 'Store name'),
                    hintText: _tx(
                        context, 'مثال: متجر النخبة', 'Example: Elite Store'),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _city,
                  enabled: !_submitted,
                  textAlign: TextAlign.right,
                  textDirection:
                      Localizations.localeOf(context).languageCode == 'ar'
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: _tx(context, 'المدينة', 'City'),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: InputDecoration(
                    labelText: _tx(context, 'تصنيف المتجر', 'Store category'),
                  ),
                  items: _categories.entries
                      .map((entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(
                                Localizations.localeOf(context).languageCode ==
                                        'ar'
                                    ? entry.value.$1
                                    : entry.value.$2),
                          ))
                      .toList(),
                  onChanged: _submitted
                      ? null
                      : (value) =>
                          setState(() => _category = value ?? 'general'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _description,
                  enabled: !_submitted,
                  maxLines: 4,
                  textAlign: TextAlign.right,
                  textDirection:
                      Localizations.localeOf(context).languageCode == 'ar'
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: _tx(context, 'وصف المتجر (اختياري)',
                        'Store description (optional)'),
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 14),
                  Text(_message!,
                      style: TextStyle(
                          color: _submitted
                              ? Colors.green
                              : Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _busy || _submitted ? null : _submit,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_submitted
                          ? _tx(context, 'تم إرسال الطلب', 'Application sent')
                          : _tx(context, 'إرسال الطلب', 'Submit application')),
                ),
              ],
            ),
          ),
        ),
      );
}
