import 'package:flutter/material.dart';
import 'package:mercato/core/api_client.dart';
import 'package:mercato/core/input_utils.dart';

String _tx(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  Map<String, dynamic>? _store;
  List<dynamic> _products = [];
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final store =
          await ApiClient.instance.get('/vendor/store') as Map<String, dynamic>;
      final products = store['status'] == 'APPROVED'
          ? await ApiClient.instance.get('/vendor/products') as List<dynamic>
          : <dynamic>[];
      if (mounted) {
        setState(() {
          _store = store;
          _products = products;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addProduct() async {
    final name = TextEditingController();
    final sku = TextEditingController();
    final price = TextEditingController();
    final stock = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tx(context, 'إضافة منتج', 'Add product')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                  labelText: _tx(context, 'اسم المنتج', 'Product name'))),
          TextField(
              controller: sku,
              decoration: InputDecoration(
                  labelText: _tx(context, 'رمز المنتج', 'SKU'))),
          TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration:
                  InputDecoration(labelText: _tx(context, 'السعر', 'Price'))),
          TextField(
              controller: stock,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText:
                      _tx(context, 'الكمية المتوفرة', 'Stock quantity'))),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_tx(context, 'إلغاء', 'Cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_tx(context, 'إضافة', 'Add'))),
        ],
      ),
    );
    if (accepted == true) {
      try {
        await ApiClient.instance.post('/vendor/products', body: {
          'name': name.text.trim(),
          'sku': sku.text.trim(),
          'price': double.tryParse(normalizeInputDecimal(price.text)) ?? 0,
          'stock': int.tryParse(normalizeInputDigits(stock.text)) ?? 0,
        });
        await _load();
      } on ApiException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.message)));
        }
      }
    }
    name.dispose();
    sku.dispose();
    price.dispose();
    stock.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final approved = _store?['status'] == 'APPROVED';
    return Directionality(
      textDirection: Localizations.localeOf(context).languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
            title: Text(_tx(context, 'لوحة تحكم المتجر', 'Store dashboard')),
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
            ]),
        floatingActionButton: approved
            ? FloatingActionButton.extended(
                onPressed: _addProduct,
                icon: const Icon(Icons.add),
                label: Text(_tx(context, 'إضافة منتج', 'Add product')))
            : null,
        body: _busy
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : ListView(padding: const EdgeInsets.all(16), children: [
                    Card(
                      child: ListTile(
                        title: Text(_store?['name']?.toString() ??
                            _tx(context, 'متجري', 'My store')),
                        subtitle: Text(
                            '${_store?['city'] ?? ''} • ${_tx(context, _store?['status'] == 'APPROVED' ? 'معتمد' : 'قيد المراجعة', _store?['status'] == 'APPROVED' ? 'Approved' : 'Pending review')}'),
                      ),
                    ),
                    if (!approved)
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(_tx(
                            context,
                            'طلب متجرك قيد المراجعة. ستتمكن من إدارة المنتجات بعد الموافقة على الطلب.',
                            'Your store application is being reviewed. You can manage products after it is approved.')),
                      ),
                    if (approved) ...[
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(_tx(context, 'المنتجات', 'Products'),
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold))),
                      ..._products.map((product) => ListTile(
                            title: Text(product['name']?.toString() ?? ''),
                            subtitle: Text(Localizations.localeOf(context)
                                        .languageCode ==
                                    'ar'
                                ? '${product['price'] ?? ''} د.ل • المخزون ${product['stock'] ?? 0}'
                                : 'LYD ${product['price'] ?? ''} • Stock ${product['stock'] ?? 0}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                try {
                                  await ApiClient.instance.delete(
                                      '/vendor/products/${product['id']}');
                                  await _load();
                                } on ApiException catch (error) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(error.message)));
                                  }
                                }
                              },
                            ),
                          )),
                    ],
                  ]),
      ),
    );
  }
}
