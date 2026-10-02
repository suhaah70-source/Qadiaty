import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mercato/core/api_client.dart';
import 'package:mercato/core/app_theme.dart';
import 'package:mercato/core/color_utils.dart';
import 'package:mercato/core/heritage_pattern.dart';
import 'package:mercato/core/media_url.dart';
import 'package:mercato/models/models.dart';
import 'package:mercato/providers/auth_provider.dart';
import 'package:mercato/providers/cart_provider.dart';
import 'package:mercato/screens/cart_screen.dart';
import 'package:mercato/screens/login_screen.dart';
import 'package:mercato/screens/product_detail_screen.dart';
import 'package:mercato/widgets/review_section.dart';

String _tx(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

class _StoreDesignElement extends StatelessWidget {
  const _StoreDesignElement({required this.element, this.onPressed});

  final Map<String, dynamic> element;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final type = element['type'] as String? ?? 'text';
    final color = hexToColor(
      element['color'] as String? ?? '#4B1724',
      fallback: AppColors.ink,
    );
    final radius = (element['radius'] as num?)?.toDouble() ?? 12;
    if (type == 'image') {
      final url = mediaUrl(element['image_url'] as String?);
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: url == null
            ? const ColoredBox(color: AppColors.ashLight)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: AppColors.ashLight),
              ),
      );
    }
    if (type == 'shape') {
      return Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: .42),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }
    final text = element['text'] as String? ?? '';
    final fontSize = (element['font_size'] as num?)?.toDouble() ?? 17;
    final label = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: type == 'button' ? Colors.white : color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: type == 'button'
          ? BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(radius))
          : null,
      child: type == 'button'
          ? InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(radius),
              child: Center(child: label),
            )
          : label,
    );
  }
}

Alignment _logoAlignment(String value) => switch (value) {
      'topLeft' => Alignment.topLeft,
      'topCenter' => Alignment.topCenter,
      'centerLeft' => Alignment.centerLeft,
      'center' => Alignment.center,
      'centerRight' => Alignment.centerRight,
      'bottomLeft' => Alignment.bottomLeft,
      'bottomCenter' => Alignment.bottomCenter,
      'bottomRight' => Alignment.bottomRight,
      _ => Alignment.topRight,
    };

class StoreScreen extends StatefulWidget {
  final String slug;

  const StoreScreen({
    super.key,
    required this.slug,
  });

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final _productsSectionKey = GlobalKey();
  StoreDetail? _store;
  bool _loading = true;
  String? _error;
  String? _selectedCategoryId;
  String _sortOrder = 'featured';

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  Future<void> _loadStore() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiClient.instance.get(
        '/stores/${widget.slug}',
        auth: false,
      ) as Map<String, dynamic>;

      final store = StoreDetail.fromJson(data);

      setState(() => _store = store);

      if (mounted) {
        context.read<CartProvider>().loadForTenant(store.tenantId);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _quickAdd(Product product) async {
    if (!context.read<AuthProvider>().isAuthenticated) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    try {
      await context
          .read<CartProvider>()
          .addItem(_store!.tenantId, product.id, 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_tx(context, 'انضاف للسلة', 'Added to cart'))));
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null || _store == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(_error ??
              _tx(context, 'تعذّر تحميل المتجر', 'Could not load store')),
        ),
      );
    }

    final store = _store!;
    final theme = store.theme;

    final primary = hexToColor(
      theme.primaryColor,
      fallback: AppColors.darkGreen,
    );

    final background = hexToColor(
      theme.backgroundColor,
      fallback: Colors.white,
    );

    final textColor = hexToColor(
      theme.textColor,
      fallback: Colors.black,
    );
    final accent = hexToColor(theme.accentColor, fallback: primary);
    final backgroundImageUrl =
        mediaUrl(theme.backgroundImageUrl ?? theme.bannerUrl);
    final useFullImage = (theme.backgroundStyle == 'image' ||
            theme.backgroundStyle == 'blend') &&
        backgroundImageUrl != null;

    final filteredProducts = _selectedCategoryId == null
        ? store.products
        : store.products
            .where((p) => p.categoryId == _selectedCategoryId)
            .toList();
    if (_sortOrder == 'price_high') {
      filteredProducts.sort((a, b) => b.price.compareTo(a.price));
    } else if (_sortOrder == 'price_low') {
      filteredProducts.sort((a, b) => a.price.compareTo(b.price));
    }
    final viewport = MediaQuery.sizeOf(context);
    final controlWidth = (viewport.width - 24).clamp(160.0, 380.0).toDouble();
    final controlLeft = (viewport.width * theme.controlsX - controlWidth / 2)
        .clamp(12.0, viewport.width - controlWidth - 12)
        .toDouble();
    final controlTop = (viewport.height * theme.controlsY - 140)
        .clamp(0.0, viewport.height - 240)
        .toDouble();

    return Directionality(
      textDirection: Localizations.localeOf(context).languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                gradient: theme.backgroundStyle == 'gradient' ||
                        theme.backgroundStyle == 'blend'
                    ? LinearGradient(colors: [
                        hexToColor(theme.backgroundGradientStart,
                            fallback: background),
                        hexToColor(theme.backgroundGradientEnd,
                            fallback: background),
                      ])
                    : null,
              ),
            ),
            if (useFullImage)
              Positioned.fill(
                child: Image.network(
                  backgroundImageUrl,
                  fit: theme.backgroundImageFit == 'contain'
                      ? BoxFit.contain
                      : BoxFit.cover,
                  color: background.withValues(
                      alpha: theme.backgroundOverlayOpacity.clamp(0, .85)),
                  colorBlendMode: BlendMode.srcOver,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: primary,
                  expandedHeight: 140,
                  pinned: true,
                  foregroundColor: Colors.white,
                  flexibleSpace: FlexibleSpaceBar(
                    title: const SizedBox.shrink(),
                    background: LayoutBuilder(builder: (context, canvas) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: primary),
                          if (mediaUrl(theme.backgroundImageUrl ??
                                  theme.bannerUrl) !=
                              null)
                            Image.network(
                                mediaUrl(theme.backgroundImageUrl ??
                                    theme.bannerUrl)!,
                                fit: theme.backgroundImageFit == 'contain'
                                    ? BoxFit.contain
                                    : BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink()),
                          Container(
                              color: background.withValues(
                                  alpha: theme.backgroundOverlayOpacity
                                      .clamp(0, .85))),
                          const HeritagePattern(),
                          Align(
                            alignment: _logoAlignment(theme.logoPosition),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: mediaUrl(theme.logoUrl) == null
                                  ? const Icon(Icons.storefront_rounded,
                                      size: 38, color: Colors.white)
                                  : ClipPath(
                                      clipper:
                                          _LogoShapeClipper(theme.logoShape),
                                      child: Image.network(
                                        mediaUrl(theme.logoUrl)!,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.storefront_rounded,
                                                size: 38, color: Colors.white),
                                      ),
                                    ),
                            ),
                          ),
                          for (final element in theme.designElements)
                            Positioned(
                              left: ((element['x'] as num?)?.toDouble() ?? 0) *
                                  canvas.maxWidth,
                              top: ((element['y'] as num?)?.toDouble() ?? 0) *
                                  canvas.maxHeight,
                              width: ((element['width'] as num?)?.toDouble() ??
                                      .5) *
                                  canvas.maxWidth,
                              height:
                                  ((element['height'] as num?)?.toDouble() ??
                                          .1) *
                                      canvas.maxHeight,
                              child: _StoreDesignElement(
                                element: element,
                                onPressed: element['type'] == 'button'
                                    ? () {
                                        final target =
                                            _productsSectionKey.currentContext;
                                        if (target != null) {
                                          Scrollable.ensureVisible(
                                            target,
                                            duration: const Duration(
                                                milliseconds: 450),
                                          );
                                        }
                                      }
                                    : null,
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
                  actions: [
                    Consumer<CartProvider>(
                      builder: (context, cart, _) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.shopping_bag_outlined,
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CartScreen(
                                      tenantId: store.tenantId,
                                      accentColor: primary,
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (cart.itemCount > 0)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: AppColors.rust,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${cart.itemCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                if (store.description.trim().isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                      child: Text(
                        store.description,
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: textColor.withValues(alpha: .82)),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: controlTop + 92,
                    child: Stack(children: [
                      Positioned(
                        top: controlTop,
                        left: controlLeft,
                        width: controlWidth,
                        height: 84,
                        child: Card(
                          color: hexToColor(theme.cardColor,
                                  fallback: Colors.white)
                              .withValues(alpha: .94),
                          child: Column(children: [
                            Expanded(
                              child: Row(children: [
                                Expanded(
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: [
                                      _CategoryChip(
                                        label: 'الكل',
                                        selected: _selectedCategoryId == null,
                                        color: accent,
                                        style: theme.categoryStyle,
                                        onTap: () => setState(
                                            () => _selectedCategoryId = null),
                                      ),
                                      ...store.categories
                                          .map((category) => _CategoryChip(
                                                label: category.name,
                                                selected: _selectedCategoryId ==
                                                    category.id,
                                                color: accent,
                                                style: theme.categoryStyle,
                                                onTap: () => setState(() =>
                                                    _selectedCategoryId =
                                                        category.id),
                                              )),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'ترتيب المنتجات',
                                  initialValue: _sortOrder,
                                  onSelected: (value) =>
                                      setState(() => _sortOrder = value),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'featured',
                                        child: Text('ترتيب المتجر')),
                                    PopupMenuItem(
                                        value: 'price_high',
                                        child: Text('الأغلى للأرخص')),
                                    PopupMenuItem(
                                        value: 'price_low',
                                        child: Text('الأرخص للأغلى')),
                                  ],
                                  child: const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 10),
                                    child: Icon(Icons.tune),
                                  ),
                                ),
                              ]),
                            ),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Padding(
                                padding: const EdgeInsetsDirectional.only(
                                    start: 12, bottom: 5),
                                child: Text(_sortOrder == 'price_high'
                                    ? 'الأغلى للأرخص'
                                    : _sortOrder == 'price_low'
                                        ? 'الأرخص للأغلى'
                                        : 'ترتيب المتجر'),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ),
                if (filteredProducts.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Text(_tx(context, 'لا توجد منتجات في هذا التصنيف',
                          'No products in this category')),
                    ),
                  )
                else
                  SliverPadding(
                    key: _productsSectionKey,
                    padding: const EdgeInsets.all(12),
                    sliver: theme.productLayout == 'list'
                        ? SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _ProductCard(
                                product: filteredProducts[index],
                                accentColor: accent,
                                cardColor: hexToColor(theme.cardColor,
                                    fallback: Colors.white),
                                textColor: textColor,
                                imageShape: theme.productImageShape,
                                imageScale: theme.productImageScale,
                                listMode: true,
                                showDescription: theme.showProductDescriptions,
                                cardStyle: theme.productCardStyle,
                                showProductCard: theme.showProductCard,
                                onQuickAdd: () =>
                                    _quickAdd(filteredProducts[index]),
                                onTap: () => Navigator.of(context)
                                    .push(MaterialPageRoute(
                                  builder: (_) => ProductDetailScreen(
                                    product: filteredProducts[index],
                                    tenantId: store.tenantId,
                                    storeSlug: store.slug,
                                    accentColor: accent,
                                  ),
                                )),
                              ),
                              childCount: filteredProducts.length,
                            ),
                          )
                        : SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: theme.productColumns.clamp(1, 4),
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio:
                                  theme.productCardStyle == 'poster'
                                      ? 0.58
                                      : theme.showProductDescriptions
                                          ? 0.66
                                          : theme.productCardStyle == 'minimal'
                                              ? 0.9
                                              : 0.72,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final product = filteredProducts[index];
                                return _ProductCard(
                                  product: product,
                                  accentColor: accent,
                                  cardColor: hexToColor(theme.cardColor,
                                      fallback: Colors.white),
                                  textColor: textColor,
                                  imageShape: theme.productImageShape,
                                  imageScale: theme.productImageScale,
                                  showDescription:
                                      theme.showProductDescriptions,
                                  cardStyle: theme.productCardStyle,
                                  showProductCard: theme.showProductCard,
                                  onQuickAdd: () => _quickAdd(product),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ProductDetailScreen(
                                          product: product,
                                          tenantId: store.tenantId,
                                          storeSlug: store.slug,
                                          accentColor: accent,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                              childCount: filteredProducts.length,
                            ),
                          ),
                  ),
                SliverToBoxAdapter(
                  child: ReviewSection(
                      storeSlug: store.slug, accentColor: primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoShapeClipper extends CustomClipper<Path> {
  const _LogoShapeClipper(this.shape);
  final String shape;

  @override
  Path getClip(Size size) {
    if (shape == 'circle') return Path()..addOval(Offset.zero & size);
    if (shape == 'triangle') {
      return Path()
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    }
    if (shape == 'diamond') {
      return Path()
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(0, size.height / 2)
        ..close();
    }
    if (shape == 'hexagon') {
      return Path()
        ..moveTo(size.width * .25, 0)
        ..lineTo(size.width * .75, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(size.width * .75, size.height)
        ..lineTo(size.width * .25, size.height)
        ..lineTo(0, size.height / 2)
        ..close();
    }
    if (shape == 'rounded') {
      return Path()
        ..addRRect(RRect.fromRectAndRadius(
            Offset.zero & size, const Radius.circular(12)));
    }
    return Path()..addRect(Offset.zero & size);
  }

  @override
  bool shouldReclip(covariant _LogoShapeClipper oldClipper) =>
      oldClipper.shape != shape;
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final String style;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.style = 'chips',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
      ),
      child: style == 'cards'
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? color : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: selected ? color : AppColors.ashLight),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontSize: 12)),
              ),
            )
          : ChoiceChip(
              label: Text(label),
              selected: selected,
              selectedColor: color,
              labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontSize: 12),
              onSelected: (_) => onTap(),
            ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final Color accentColor;
  final Color cardColor;
  final Color textColor;
  final String imageShape;
  final double imageScale;
  final VoidCallback onTap;
  final bool listMode;
  final bool showDescription;
  final String cardStyle;
  final bool showProductCard;
  final VoidCallback? onQuickAdd;

  const _ProductCard({
    required this.product,
    required this.accentColor,
    required this.cardColor,
    required this.textColor,
    required this.imageShape,
    this.imageScale = .85,
    required this.onTap,
    this.listMode = false,
    this.showDescription = false,
    this.cardStyle = 'classic',
    this.showProductCard = true,
    this.onQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (listMode) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: showProductCard ? const EdgeInsets.all(8) : EdgeInsets.zero,
          decoration: showProductCard
              ? BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accentColor.withValues(alpha: .2)),
                )
              : null,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: showDescription ? 128 : 106,
              child: Row(children: [
                Container(
                  width: 86,
                  height: 86,
                  color: cardColor.withValues(alpha: .5),
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 86 * imageScale,
                    height: 86 * imageScale,
                    child: ClipPath(
                      clipper: _ShapeClipper(imageShape),
                      child: mediaUrl(product.imageUrl) == null
                          ? const Icon(Icons.image_outlined,
                              color: AppColors.ashLight)
                          : Image.network(mediaUrl(product.imageUrl)!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image_outlined)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Text(product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: textColor)),
                      if (showDescription &&
                          (product.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(product.description ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: textColor.withValues(alpha: .7))),
                      ],
                    ])),
                if (onQuickAdd != null)
                  IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      onPressed: onQuickAdd,
                      icon: const Icon(Icons.add, color: AppColors.rust))
                else
                  Icon(Icons.chevron_left, color: accentColor),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: showProductCard ? const EdgeInsets.all(8) : EdgeInsets.zero,
      decoration: showProductCard
          ? BoxDecoration(
              color: cardColor,
              borderRadius:
                  BorderRadius.circular(cardStyle == 'minimal' ? 4 : 14),
              border: Border.all(color: accentColor.withValues(alpha: .2)),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(children: [
                  Positioned.fill(
                    child: LayoutBuilder(builder: (context, constraints) {
                      final imageWidth = constraints.maxWidth * imageScale;
                      final imageHeight = constraints.maxHeight * imageScale;
                      return Container(
                        color: cardColor.withValues(alpha: .45),
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: imageWidth,
                          height: imageHeight,
                          child: Hero(
                            tag: 'product-image-${product.id}',
                            child: ClipPath(
                              clipper: _ShapeClipper(imageShape),
                              child: mediaUrl(product.imageUrl) == null
                                  ? const ColoredBox(
                                      color: AppColors.canvas,
                                      child: Center(
                                          child: Icon(Icons.image_outlined,
                                              color: AppColors.ashLight,
                                              size: 32)))
                                  : Image.network(mediaUrl(product.imageUrl)!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Center(
                                              child: Icon(
                                                  Icons.broken_image_outlined,
                                                  color: AppColors.ashLight,
                                                  size: 32))),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  if (onQuickAdd != null)
                    PositionedDirectional(
                      top: 7,
                      start: 7,
                      child: IconButton.filled(
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: .95),
                            foregroundColor: accentColor),
                        onPressed: onQuickAdd,
                        icon: const Icon(Icons.add_shopping_cart_rounded,
                            size: 18),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: textColor,
                ),
              ),
              if (showDescription &&
                  (product.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(product.description ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10, color: textColor.withValues(alpha: .7))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ShapeClipper extends CustomClipper<Path> {
  const _ShapeClipper(this.shape);
  final String shape;

  @override
  Path getClip(Size size) {
    if (shape == 'triangle') {
      return Path()
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    }
    if (shape == 'diamond') {
      return Path()
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(0, size.height / 2)
        ..close();
    }
    if (shape == 'circle') return Path()..addOval(Offset.zero & size);
    if (shape == 'rounded')
      return Path()
        ..addRRect(RRect.fromRectAndRadius(
            Offset.zero & size, const Radius.circular(10)));
    return Path()..addRect(Offset.zero & size);
  }

  @override
  bool shouldReclip(covariant _ShapeClipper oldClipper) =>
      oldClipper.shape != shape;
}
