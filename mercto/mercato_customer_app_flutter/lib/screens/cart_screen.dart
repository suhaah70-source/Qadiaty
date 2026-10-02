import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mercato/core/api_client.dart';
import 'package:mercato/core/input_utils.dart';
import 'package:mercato/core/app_theme.dart';
import 'package:mercato/core/media_url.dart';
import 'package:mercato/models/models.dart';
import 'package:mercato/providers/cart_provider.dart';
import 'package:mercato/providers/auth_provider.dart';
import 'package:mercato/providers/location_provider.dart';
import 'package:mercato/screens/order_confirmation_screen.dart';
import 'package:mercato/screens/map_picker_screen.dart';

String _tx(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

class CartScreen extends StatefulWidget {
  // Kept to support navigation from an individual store screen.
  final String tenantId;
  final Color accentColor;

  const CartScreen(
      {super.key, required this.tenantId, required this.accentColor});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _checkingOut = false;
  String? _error;
  final Map<String, String> _storeNotes = {};
  final _addressFormKey = GlobalKey<FormState>();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _cityController.dispose();
    _districtController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _askForAddress() async {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final position = await context.read<LocationProvider>().locate(force: true);
    if (!mounted) return null;
    double? latitude = position?.latitude;
    double? longitude = position?.longitude;
    if (position != null) {
      _cityController.text = LocationProvider.nearestLibyanCity(
          position.latitude, position.longitude,
          arabic: arabic);
      _districtController.text =
          arabic ? 'موقعي الحالي' : 'My current location';
      _addressController.text =
          _coordinateAddress(position.latitude, position.longitude, arabic);
    }
    if (_phoneController.text.isEmpty) {
      _phoneController.text = context.read<AuthProvider>().phone ?? '';
    }
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Directionality(
          textDirection: Localizations.localeOf(context).languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: AlertDialog(
            title: Text(
                _tx(context, "أدخل عنوان التوصيل", "Enter delivery address")),
            content: SingleChildScrollView(
              child: Form(
                key: _addressFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _addressField(
                        _cityController, _tx(context, "المدينة", "City")),
                    const SizedBox(height: 10),
                    _addressField(_districtController,
                        _tx(context, "المنطقة", "District")),
                    const SizedBox(height: 10),
                    _addressField(_addressController,
                        _tx(context, "العنوان بالتفصيل", "Street address")),
                    const SizedBox(height: 10),
                    _addressField(
                      _phoneController,
                      _tx(context, "رقم الهاتف", "Phone number"),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final point = await Navigator.of(dialogContext)
                            .push<Map<String, dynamic>>(
                          MaterialPageRoute(
                            builder: (_) => MapPickerScreen(
                              initialLatitude: latitude,
                              initialLongitude: longitude,
                            ),
                            fullscreenDialog: true,
                          ),
                        );
                        if (point != null) {
                          final selectedLatitude = point['latitude']!;
                          final selectedLongitude = point['longitude']!;
                          setDialogState(() {
                            latitude = selectedLatitude;
                            longitude = selectedLongitude;
                            _cityController.text = point['city']?.toString() ??
                                _cityController.text;
                            _districtController.text =
                                arabic ? 'موقعي الحالي' : 'My current location';
                            _addressController.text = _coordinateAddress(
                                selectedLatitude, selectedLongitude, arabic);
                          });
                        }
                      },
                      icon: const Icon(Icons.map_outlined),
                      label: Text(latitude == null
                          ? _tx(context, "اختيار الموقع", "Choose location")
                          : _tx(context, "تغيير الموقع", "Change location")),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(_tx(context, "إلغاء", "Cancel")),
              ),
              FilledButton(
                onPressed: () {
                  if (!_addressFormKey.currentState!.validate()) return;
                  Navigator.pop(dialogContext, {
                    'city': _cityController.text.trim(),
                    'district': _districtController.text.trim(),
                    'address_text': _addressController.text.trim(),
                    'phone': normalizeInputDigits(_phoneController.text.trim()),
                    'is_default': true,
                    if (latitude != null) 'latitude': latitude,
                    if (longitude != null) 'longitude': longitude,
                  });
                },
                child: Text(_tx(context, "حفظ العنوان", "Save address")),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addressField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      decoration: InputDecoration(labelText: label),
      validator: (value) => (value == null || value.trim().length < 3)
          ? _tx(context, "يرجى إدخال بيانات صحيحة", "Enter valid information")
          : null,
    );
  }

  String _coordinateAddress(double latitude, double longitude, bool arabic) {
    final coords =
        '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    return arabic
        ? 'موقع التسليم المحدد على الخريطة ($coords)'
        : 'Delivery point selected on the map ($coords)';
  }

  Future<void> _checkout() async {
    final address = await _askForAddress();
    if (address == null || !mounted) return;
    final cartProvider = context.read<CartProvider>();

    setState(() {
      _checkingOut = true;
      _error = null;
    });
    try {
      final savedAddress = await ApiClient.instance.post(
        '/addresses',
        body: address,
      ) as Map<String, dynamic>;
      final orders = await cartProvider.checkout(
        addressId: savedAddress['id'] as String,
        storeNotes: _storeNotes,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(
            orders: orders,
            accentColor: widget.accentColor,
          ),
        ),
      );
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = _tx(context, "تعذر إتمام الطلب. حاول مرة أخرى.",
          "Could not place your order. Please try again."));
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  Widget _storeCartCard(
      BuildContext context, CartProvider cartProvider, List<CartItem> items) {
    final store = items.first;
    final color = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.ashLight.withValues(alpha: .6)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: color.surfaceContainerHighest,
              backgroundImage: mediaUrl(store.storeLogoUrl) == null
                  ? null
                  : NetworkImage(mediaUrl(store.storeLogoUrl)!),
              child: mediaUrl(store.storeLogoUrl) == null
                  ? const Icon(Icons.storefront_outlined)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(store.storeName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700))),
            const Icon(Icons.chevron_right_rounded),
          ]),
        ),
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  width: 76,
                  height: 76,
                  color: Colors.white,
                  child: mediaUrl(items[index].imageUrl) == null
                      ? const Icon(Icons.image_outlined,
                          color: AppColors.ashLight)
                      : Image.network(mediaUrl(items[index].imageUrl)!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image_outlined)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(items[index].productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, height: 1.3)),
                    const SizedBox(height: 8),
                    Text(
                        '${items[index].unitPrice.toStringAsFixed(2)} ${_tx(context, 'د.ل', 'LYD')}',
                        style: TextStyle(
                            color: widget.accentColor,
                            fontWeight: FontWeight.w700)),
                  ])),
              Column(children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: _tx(context, 'حذف', 'Remove'),
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.rust, size: 21),
                  onPressed: () => cartProvider.removeItem(items[index].id),
                ),
                Container(
                  decoration: BoxDecoration(
                      color: color.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        onPressed: items[index].quantity > 1
                            ? () => cartProvider.updateQuantity(
                                items[index].id,
                                items[index].productId,
                                items[index].quantity - 1)
                            : null,
                        icon: const Icon(Icons.remove, color: AppColors.rust)),
                    Text('${items[index].quantity}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        onPressed: items[index].quantity < items[index].stock
                            ? () => cartProvider.updateQuantity(
                                items[index].id,
                                items[index].productId,
                                items[index].quantity + 1)
                            : null,
                        icon: const Icon(Icons.add, color: AppColors.rust)),
                  ]),
                ),
              ]),
            ]),
          ),
        ],
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 15),
          child: Column(children: [
            TextField(
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              minLines: 1,
              maxLines: 3,
              maxLength: 1000,
              decoration: InputDecoration(
                counterText: '',
                labelText: _tx(context, 'ملاحظة للمتجر', 'Note for the store'),
                hintText: _tx(context, 'اكتب ملاحظتك هنا...', 'Add a note...'),
                prefixIcon: const Icon(Icons.sticky_note_2_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onChanged: (value) => _storeNotes[store.storeId] = value,
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.add),
              label: Text(_tx(context, 'إضافة منتجات', 'Add more items')),
            ),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Localizations.localeOf(context).languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(_tx(context, "السلة", "Cart"))),
        body: Consumer<CartProvider>(
          builder: (context, cartProvider, _) {
            final cart = cartProvider.cart;
            if (cartProvider.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (cart == null || cart.items.isEmpty) {
              return Center(
                  child: Text(_tx(context, "سلتك فارغة. أضف منتجات للمتابعة.",
                      "Your cart is empty. Add products to continue.")));
            }

            final grouped = <String, List<CartItem>>{};
            for (final item in cart.items) {
              grouped.putIfAbsent(item.storeId, () => []).add(item);
            }
            final stores = grouped.values.toList()
              ..sort((a, b) => a.first.storeName.compareTo(b.first.storeName));
            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: stores.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) =>
                        _storeCartCard(context, cartProvider, stores[index]),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border:
                          Border(top: BorderSide(color: AppColors.ashLight)),
                    ),
                    child: Column(
                      children: [
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!,
                              style: const TextStyle(
                                  color: AppColors.rust, fontSize: 12)),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _checkingOut ? null : _checkout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _checkingOut
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_tx(context, 'استمرار', 'Continue')),
                                      Text(
                                          '${cart.subtotal.toStringAsFixed(2)} ${_tx(context, 'د.ل', 'LYD')}'),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
