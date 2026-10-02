import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mercato/core/api_client.dart';
import 'package:mercato/core/app_theme.dart';
import 'package:mercato/core/media_url.dart';
import 'package:mercato/models/models.dart';
import 'package:mercato/providers/auth_provider.dart';
import 'package:mercato/providers/cart_provider.dart';
import 'package:mercato/screens/login_screen.dart';
import 'package:mercato/screens/cart_screen.dart';
import 'package:mercato/widgets/review_section.dart';

String _tx(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final String tenantId;
  final String storeSlug;
  final Color accentColor;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.tenantId,
    required this.storeSlug,
    required this.accentColor,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  bool _adding = false;
  String? _error;

  Future<void> _addToCart() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      await context
          .read<CartProvider>()
          .addItem(widget.tenantId, widget.product.id, _quantity);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(_tx(context, 'تمت الإضافة إلى السلة', 'Added to cart'))),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final outOfStock = product.stock <= 0;

    return Directionality(
      textDirection: Localizations.localeOf(context).languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title:
              Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            Consumer<CartProvider>(
                builder: (context, cart, _) => Padding(
                      padding: const EdgeInsetsDirectional.only(end: 10),
                      child: IconButton(
                        tooltip: _tx(context, 'السلة', 'Cart'),
                        onPressed: () =>
                            Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => CartScreen(
                              tenantId: widget.tenantId,
                              accentColor: widget.accentColor),
                        )),
                        icon: Badge(
                          isLabelVisible: cart.itemCount > 0,
                          label: Text('${cart.itemCount}'),
                          child: const Icon(Icons.shopping_bag_outlined),
                        ),
                      ),
                    )),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'product-image-${product.id}',
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.canvas,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: mediaUrl(product.imageUrl) == null
                              ? const Center(
                                  child: Icon(Icons.image_outlined,
                                      size: 48, color: AppColors.ashLight))
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                      mediaUrl(product.imageUrl)!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) =>
                                          const Center(
                                              child: Icon(
                                                  Icons.broken_image_outlined,
                                                  size: 48,
                                                  color: AppColors.ashLight))),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(product.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      Localizations.localeOf(context).languageCode == 'ar'
                          ? '${product.price.toStringAsFixed(2)} د.ل'
                          : 'LYD ${product.price.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: widget.accentColor),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      outOfStock
                          ? _tx(context, 'نفد من المخزون', 'Out of stock')
                          : _tx(context, 'متوفر (${product.stock} قطعة)',
                              'Available (${product.stock} items)'),
                      style: TextStyle(
                        fontSize: 13,
                        color: outOfStock ? AppColors.rust : AppColors.jade,
                      ),
                    ),
                    if (product.description != null &&
                        product.description!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(_tx(context, 'الوصف', 'Description'),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(product.description!,
                          style: const TextStyle(
                              color: Colors.black87, height: 1.5)),
                    ],
                    ReviewSection(
                        storeSlug: widget.storeSlug,
                        productId: product.id,
                        accentColor: widget.accentColor),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(
                              color: AppColors.rust, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
            if (!outOfStock)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _QuantityStepper(
                        quantity: _quantity,
                        max: product.stock,
                        onChanged: (q) => setState(() => _quantity = q),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _adding ? null : _addToCart,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _adding
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_tx(
                                        context, 'أضف للسلة', 'Add to cart')),
                                    Text(
                                      '${(product.price * _quantity).toStringAsFixed(2)} ${_tx(context, 'د.ل', 'LYD')}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final int max;
  final ValueChanged<int> onChanged;

  const _QuantityStepper(
      {required this.quantity, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.ashLight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
          ),
          Text('$quantity',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: quantity < max ? () => onChanged(quantity + 1) : null,
          ),
        ],
      ),
    );
  }
}
