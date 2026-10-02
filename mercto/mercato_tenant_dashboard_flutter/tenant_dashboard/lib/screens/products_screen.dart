import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/constants.dart';
import '../core/input_utils.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';

const _statusColors = {
  'DRAFT': AppColors.ash,
  'ACTIVE': AppColors.jade,
  'OUT_OF_STOCK': AppColors.rust,
  'ARCHIVED': AppColors.ash,
};

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> _products = [];
  List<Category> _categories = [];
  bool _loading = true;

  String? get _tenantId => context.read<AuthProvider>().tenantId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tenantId = _tenantId;
    if (tenantId == null) return;
    setState(() => _loading = true);
    final p = await ApiClient.instance.get('/tenants/$tenantId/products')
        as List<dynamic>;
    final c = await ApiClient.instance.get('/tenants/$tenantId/categories')
        as List<dynamic>;
    if (!mounted) return;
    setState(() {
      _products =
          p.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
      _categories =
          c.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
      _loading = false;
    });
  }

  Future<void> _delete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text('هل تريد حذف المنتج «${product.name}»؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('حذف', style: TextStyle(color: AppColors.rust))),
        ],
      ),
    );
    if (confirmed != true) return;
    await ApiClient.instance
        .delete('/tenants/$_tenantId/products/${product.id}');
    _load();
  }

  void _openForm({Product? editing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductFormSheet(
        editing: editing,
        categories: _categories,
        tenantId: _tenantId!,
        onSaved: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المنتجات',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface)),
                    Text('${_products.length} منتج في متجرك',
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة منتج'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _loading
                ? const Center(
                    child: Text('جارٍ تحميل المنتجات...',
                        style: TextStyle(color: AppColors.ash)))
                : _products.isEmpty
                    ? const Center(
                        child: Text('لا توجد منتجات بعد. أضف أول منتج لمتجرك.',
                            style: TextStyle(color: AppColors.ash)))
                    : Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.ashLight),
                        ),
                        child: ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          itemCount: _products.length,
                          onReorderItem: (oldIndex, newIndex) async {
                            final reordered = List<Product>.of(_products);
                            final product = reordered.removeAt(oldIndex);
                            reordered.insert(newIndex, product);
                            setState(() => _products = reordered);
                            try {
                              await ApiClient.instance.patch(
                                '/tenants/$_tenantId/products/order',
                                body: {
                                  'product_ids':
                                      reordered.map((item) => item.id).toList(),
                                },
                              );
                            } on ApiException {
                              await _load();
                            }
                          },
                          itemBuilder: (context, i) {
                            final p = _products[i];
                            final color =
                                _statusColors[p.status] ?? AppColors.ash;
                            return ListTile(
                              key: ValueKey(p.id),
                              title: Text(p.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5)),
                              subtitle: Text(
                                  'رمز المنتج: ${p.sku} · المخزون: ${p.stock}',
                                  style: const TextStyle(
                                      fontSize: 11.5, color: AppColors.ash)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${p.price.toStringAsFixed(0)} د.ل',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6)),
                                    child: Text(
                                        kProductStatusLabels[p.status] ??
                                            p.status,
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            color: color,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 17),
                                      color: AppColors.ash,
                                      onPressed: () => _openForm(editing: p)),
                                  IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 17),
                                      color: AppColors.rust,
                                      onPressed: () => _delete(p)),
                                  ReorderableDragStartListener(
                                      index: i,
                                      child: const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Icon(Icons.drag_handle,
                                            color: AppColors.ash),
                                      )),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ProductFormSheet extends StatefulWidget {
  final Product? editing;
  final List<Category> categories;
  final String tenantId;
  final VoidCallback onSaved;

  const _ProductFormSheet(
      {required this.editing,
      required this.categories,
      required this.tenantId,
      required this.onSaved});

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late final _sku = TextEditingController(text: widget.editing?.sku ?? '');
  late final _price =
      TextEditingController(text: widget.editing?.price.toString() ?? '');
  late final _stock =
      TextEditingController(text: widget.editing?.stock.toString() ?? '0');
  late final _description =
      TextEditingController(text: widget.editing?.description ?? '');
  String? _categoryId;
  String _status = 'DRAFT';
  String? _error;
  String? _imageUrl;
  bool _uploadingImage = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.editing?.categoryId;
    _status = widget.editing?.status ?? 'DRAFT';
    _imageUrl = widget.editing?.imageUrl;
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final body = {
        'name': _name.text,
        'sku': _sku.text.isEmpty ? widget.editing?.sku : _sku.text,
        'description': _description.text.isEmpty ? null : _description.text,
        'price': double.tryParse(normalizeInputDecimal(_price.text)) ?? 0,
        'stock': int.tryParse(normalizeInputDigits(_stock.text)) ?? 0,
        'category_id': _categoryId,
        'status': _status,
        'image_url': _imageUrl,
      };
      if (widget.editing != null) {
        await ApiClient.instance.patch(
            '/tenants/${widget.tenantId}/products/${widget.editing!.id}',
            body: body);
      } else {
        await ApiClient.instance
            .post('/tenants/${widget.tenantId}/products', body: body);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickProductImage() async {
    try {
      final image = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 88);
      if (image == null) return;
      setState(() => _uploadingImage = true);
      final url = await ApiClient.instance
          .uploadVendorImage(await image.readAsBytes(), image.name);
      if (mounted) setState(() => _imageUrl = url);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر اختيار صورة المنتج أو رفعها');
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing != null;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24))),
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(editing ? 'تعديل المنتج' : 'إضافة منتج',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700))),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),
            _label('صورة المنتج'),
            InkWell(
              onTap: _uploadingImage ? null : _pickProductImage,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 132,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.ashLight),
                ),
                clipBehavior: Clip.antiAlias,
                child: _imageUrl == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 34),
                          SizedBox(height: 8),
                          Text('اضغط هنا لاختيار صورة المنتج من الاستديو'),
                        ],
                      )
                    : Image.network(
                        _imageUrl!.startsWith('http')
                            ? _imageUrl!
                            : '${kApiBaseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '')}$_imageUrl',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined, size: 36),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _uploadingImage ? null : _pickProductImage,
              icon: _uploadingImage
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.photo_library_outlined),
              label: Text(_uploadingImage
                  ? 'جارٍ رفع الصورة...'
                  : 'اختيار صورة من الاستديو'),
            ),
            const SizedBox(height: 8),
            _label('اسم المنتج'),
            TextField(
                controller: _name,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right),
            if (!editing) ...[
              const SizedBox(height: 12),
              _label('رمز المنتج (SKU)'),
              TextField(
                  controller: _sku,
                  keyboardType: TextInputType.text,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _label('السعر (د.ل)'),
                      TextField(
                          controller: _price,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true)),
                    ])),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _label('الكمية المتوفرة'),
                      TextField(
                          controller: _stock,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          keyboardType: TextInputType.number),
                    ])),
              ],
            ),
            const SizedBox(height: 12),
            _label('التصنيف'),
            DropdownButtonFormField<String?>(
              initialValue: _categoryId,
              items: [
                const DropdownMenuItem(value: null, child: Text('بدون تصنيف')),
                ...widget.categories.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            _label('حالة المنتج'),
            DropdownButtonFormField<String>(
              initialValue: _status,
              items: kProductStatusLabels.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 12),
            _label('وصف المنتج'),
            TextField(
                controller: _description,
                maxLines: 3,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right),
            const SizedBox(height: 12),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(color: AppColors.rust, fontSize: 12)),
            ],
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving
                  ? 'جارٍ الحفظ...'
                  : (editing ? 'حفظ التعديلات' : 'إضافة المنتج')),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ash)),
      );
}
