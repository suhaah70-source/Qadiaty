import 'package:flutter/material.dart';
import 'package:mercato/core/api_client.dart';
import 'package:mercato/core/input_utils.dart';
import 'package:mercato/providers/auth_provider.dart';
import 'package:mercato/providers/location_provider.dart';
import 'package:mercato/screens/map_picker_screen.dart';
import 'package:provider/provider.dart';

String _tx(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  List<Map<String, dynamic>> _addresses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ApiClient.instance.get('/addresses') as List<dynamic>;
      if (mounted) {
        setState(() => _addresses = rows.cast<Map<String, dynamic>>());
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addAddress() async {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final position = await context.read<LocationProvider>().locate(force: true);
    if (!mounted) return;
    final city = position == null
        ? ''
        : LocationProvider.nearestLibyanCity(
            position.latitude, position.longitude,
            arabic: arabic);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AddressEditor(
        initialLatitude: position?.latitude,
        initialLongitude: position?.longitude,
        initialCity: city,
        initialPhone: context.read<AuthProvider>().phone ?? '',
        arabic: arabic,
      ),
    );
    if (result == null || !mounted) return;
    try {
      if (_addresses.isEmpty) result['is_default'] = true;
      await ApiClient.instance.post('/addresses', body: result);
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await ApiClient.instance.delete('/addresses/$id');
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: Localizations.localeOf(context).languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
              title:
                  Text(_tx(context, 'العناوين المحفوظة', 'Saved addresses'))),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addAddress,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(_tx(context, 'إضافة عنوان', 'Add address')),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : _addresses.isEmpty
                      ? Center(
                          child: Text(_tx(context, 'لا توجد عناوين محفوظة بعد',
                              'No saved addresses yet')))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                            itemCount: _addresses.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final row = _addresses[index];
                              final lat = row['latitude'];
                              final lon = row['longitude'];
                              final city = row['city']?.toString() ?? '';
                              final district =
                                  row['district']?.toString() ?? '';
                              final coordinates = lat == null || lon == null
                                  ? ''
                                  : '\n$lat, $lon';
                              return Card(
                                child: ListTile(
                                  leading:
                                      const Icon(Icons.location_on_outlined),
                                  title: Text(Localizations.localeOf(context)
                                              .languageCode ==
                                          'ar'
                                      ? '$city، $district'
                                      : '$district, $city'),
                                  subtitle: Text(
                                    '${row['address_text'] ?? ''}\n${row['phone'] ?? ''}$coordinates',
                                  ),
                                  isThreeLine: true,
                                  trailing: IconButton(
                                    tooltip: _tx(context, 'حذف العنوان',
                                        'Delete address'),
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () =>
                                        _delete(row['id'] as String),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      );
}

class _AddressEditor extends StatefulWidget {
  const _AddressEditor({
    this.initialLatitude,
    this.initialLongitude,
    this.initialCity = '',
    this.initialPhone = '',
    required this.arabic,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final String initialCity;
  final String initialPhone;
  final bool arabic;

  @override
  State<_AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends State<_AddressEditor> {
  final _key = GlobalKey<FormState>();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _details = TextEditingController();
  final _phone = TextEditingController();
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialLatitude;
    _longitude = widget.initialLongitude;
    _city.text = widget.initialCity;
    _phone.text = widget.initialPhone;
    if (_latitude != null && _longitude != null) {
      _district.text = widget.arabic ? 'موقعي الحالي' : 'My current location';
      _details.text =
          _coordinateAddress(_latitude!, _longitude!, widget.arabic);
    }
  }

  static String _coordinateAddress(
      double latitude, double longitude, bool arabic) {
    final coords =
        '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    return arabic
        ? 'موقع التسليم المحدد على الخريطة ($coords)'
        : 'Delivery point selected on the map ($coords)';
  }

  @override
  void dispose() {
    _city.dispose();
    _district.dispose();
    _details.dispose();
    _phone.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController controller, String label,
          {TextInputType? keyboard}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboard,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          decoration: InputDecoration(labelText: label),
          validator: (value) => (value ?? '').trim().length < 2
              ? _tx(
                  context, 'يرجى إدخال $label بشكل صحيح', 'Enter valid $label')
              : null,
        ),
      );

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: Localizations.localeOf(context).languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: AlertDialog(
          title: Text(_tx(context, 'إضافة عنوان جديد', 'Add a new address')),
          content: SizedBox(
            width: 420,
            child: Form(
              key: _key,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _field(_city, _tx(context, 'المدينة', 'City')),
                  _field(_district, _tx(context, 'المنطقة', 'District')),
                  _field(_details,
                      _tx(context, 'العنوان بالتفصيل', 'Street address')),
                  _field(_phone, _tx(context, 'رقم الهاتف', 'Phone number'),
                      keyboard: TextInputType.phone),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final point = await Navigator.of(context)
                          .push<Map<String, dynamic>>(
                        MaterialPageRoute(
                          builder: (_) => MapPickerScreen(
                            initialLatitude: _latitude,
                            initialLongitude: _longitude,
                          ),
                          fullscreenDialog: true,
                        ),
                      );
                      if (point != null) {
                        final latitude = point['latitude']!;
                        final longitude = point['longitude']!;
                        setState(() {
                          _latitude = latitude;
                          _longitude = longitude;
                          _city.text = point['city']?.toString() ?? _city.text;
                          _district.text = widget.arabic
                              ? 'موقعي الحالي'
                              : 'My current location';
                          _details.text = _coordinateAddress(
                              latitude, longitude, widget.arabic);
                        });
                      }
                    },
                    icon: const Icon(Icons.map_outlined),
                    label: Text(_latitude == null
                        ? _tx(context, 'تحديد الموقع على الخريطة',
                            'Choose a location on the map')
                        : _tx(context, 'تم تحديد الموقع', 'Location selected')),
                  ),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_tx(context, 'إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (!_key.currentState!.validate()) return;
                Navigator.pop(context, {
                  'city': _city.text.trim(),
                  'district': _district.text.trim(),
                  'address_text': _details.text.trim(),
                  'phone': normalizeInputDigits(_phone.text.trim()),
                  'is_default': false,
                  if (_latitude != null) 'latitude': _latitude,
                  if (_longitude != null) 'longitude': _longitude,
                });
              },
              child: Text(_tx(context, 'حفظ العنوان', 'Save address')),
            ),
          ],
        ),
      );
}
