class Tenant {
  final String id;
  final String code;
  final String slug;
  final String name;
  final String status;
  final String? logoUrl;
  final String logoShape;
  final String? bannerUrl;
  final String? description;
  final String? city;
  final String primaryColor;
  final String storeCategory;

  Tenant({
    required this.id,
    required this.code,
    required this.slug,
    required this.name,
    required this.status,
    this.logoUrl,
    this.logoShape = 'circle',
    this.bannerUrl,
    this.description,
    this.city,
    this.primaryColor = '#14213D',
    this.storeCategory = 'general',
  });

  factory Tenant.fromJson(Map<String, dynamic> json) => Tenant(
        id: json['id'] as String,
        code: json['code'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        status: json['status'] as String,
        logoUrl: json['logo_url'] as String?,
        logoShape: json['logo_shape'] as String? ?? 'circle',
        bannerUrl: json['banner_url'] as String?,
        description: json['description'] as String?,
        city: json['city'] as String?,
        primaryColor: json['primary_color'] as String? ?? '#14213D',
        storeCategory: json['store_category'] as String? ?? 'general',
      );
}

class StoreTheme {
  final String primaryColor;
  final String secondaryColor;
  final String backgroundColor;
  final String textColor;
  final String? logoUrl;
  final String? bannerUrl;
  final String logoShape;
  final String productImageShape;
  final double productImageScale;
  final String productLayout;
  final int productColumns;
  final String categoryStyle;
  final String productCardStyle;
  final bool showProductCard;
  final bool showProductDescriptions;
  final String? backgroundImageUrl;
  final String backgroundImageFit;
  final double backgroundOverlayOpacity;
  final String logoPosition;
  final String backgroundStyle;
  final String backgroundGradientStart;
  final String backgroundGradientEnd;
  final String accentColor;
  final String cardColor;
  final double controlsX;
  final double controlsY;
  final List<Map<String, dynamic>> designElements;

  StoreTheme({
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.textColor,
    this.logoUrl,
    this.bannerUrl,
    this.logoShape = 'circle',
    this.productImageShape = 'rounded',
    this.productImageScale = 0.85,
    this.productLayout = 'grid',
    this.productColumns = 2,
    this.categoryStyle = 'chips',
    this.productCardStyle = 'classic',
    this.showProductCard = true,
    this.showProductDescriptions = false,
    this.backgroundImageUrl,
    this.backgroundImageFit = 'contain',
    this.backgroundOverlayOpacity = 0.12,
    this.logoPosition = 'topRight',
    this.backgroundStyle = 'solid',
    this.backgroundGradientStart = '#6E8649',
    this.backgroundGradientEnd = '#071E07',
    this.accentColor = '#477023',
    this.cardColor = '#FFFFFF',
    this.controlsX = 0.5,
    this.controlsY = 0.18,
    this.designElements = const [],
  });

  factory StoreTheme.fromJson(Map<String, dynamic> json) => StoreTheme(
        primaryColor: json['primary_color'] as String? ?? '#0D330E',
        secondaryColor: json['secondary_color'] as String? ?? '#477023',
        backgroundColor: json['background_color'] as String? ?? '#F3F5EF',
        textColor: json['text_color'] as String? ?? '#071E07',
        logoUrl: json['logo_url'] as String?,
        bannerUrl: json['banner_url'] as String?,
        logoShape: json['logo_shape'] as String? ?? 'circle',
        productImageShape: json['product_image_shape'] as String? ?? 'rounded',
        productImageScale:
            (json['product_image_scale'] as num?)?.toDouble() ?? 0.85,
        productLayout: json['product_layout'] as String? ?? 'grid',
        productColumns: (json['product_columns'] as num?)?.toInt() ?? 2,
        categoryStyle: json['category_style'] as String? ?? 'chips',
        productCardStyle: json['product_card_style'] as String? ?? 'classic',
        showProductCard: json['show_product_card'] as bool? ?? true,
        showProductDescriptions:
            json['show_product_descriptions'] as bool? ?? false,
        backgroundImageUrl: json['background_image_url'] as String?,
        backgroundImageFit:
            json['background_image_fit'] as String? ?? 'contain',
        backgroundOverlayOpacity:
            (json['background_overlay_opacity'] as num?)?.toDouble() ?? 0.12,
        logoPosition: json['logo_position'] as String? ?? 'topRight',
        backgroundStyle: json['background_style'] as String? ?? 'solid',
        backgroundGradientStart:
            json['background_gradient_start'] as String? ?? '#6E8649',
        backgroundGradientEnd:
            json['background_gradient_end'] as String? ?? '#071E07',
        accentColor: json['accent_color'] as String? ?? '#477023',
        cardColor: json['card_color'] as String? ?? '#FFFFFF',
        controlsX: (json['controls_x'] as num?)?.toDouble() ?? 0.5,
        controlsY: (json['controls_y'] as num?)?.toDouble() ?? 0.18,
        designElements: (json['design_elements'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(),
      );
}

class Category {
  final String id;
  final String name;
  final String slug;

  Category({required this.id, required this.name, required this.slug});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
      );
}

class Product {
  final String id;
  final String name;
  final String? description;
  final double price;
  final int stock;
  final String sku;
  final String status;
  final String? categoryId;
  final String? imageUrl;
  final int sortOrder;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.stock,
    required this.sku,
    required this.status,
    this.categoryId,
    this.imageUrl,
    this.sortOrder = 0,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        price: (json['price'] as num).toDouble(),
        stock: json['stock'] as int,
        sku: json['sku'] as String,
        status: json['status'] as String,
        categoryId: json['category_id'] as String?,
        imageUrl: json['image_url'] as String?,
        sortOrder: json['sort_order'] as int? ?? 0,
      );
}

class StoreDetail {
  final String tenantId;
  final String slug;
  final String name;
  final String description;
  final StoreTheme theme;
  final List<Category> categories;
  final List<Product> products;

  StoreDetail({
    required this.tenantId,
    required this.slug,
    required this.name,
    required this.description,
    required this.theme,
    required this.categories,
    required this.products,
  });

  factory StoreDetail.fromJson(Map<String, dynamic> json) => StoreDetail(
        tenantId: json['tenant_id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        theme: StoreTheme.fromJson(json['theme'] as Map<String, dynamic>),
        categories: (json['categories'] as List<dynamic>)
            .map((e) => Category.fromJson(e as Map<String, dynamic>))
            .toList(),
        products: (json['products'] as List<dynamic>)
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CartItem {
  final String id;
  final String productId;
  final String productName;
  final String storeId;
  final String storeName;
  final String? storeLogoUrl;
  final String? imageUrl;
  final int quantity;
  final int stock;
  final double unitPrice;

  CartItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.storeId,
    required this.storeName,
    this.storeLogoUrl,
    this.imageUrl,
    required this.quantity,
    this.stock = 99,
    required this.unitPrice,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        id: json['id'] as String,
        productId: json['product_id'] as String,
        productName: json['product_name'] as String? ?? 'منتج',
        storeId: json['store_id'] as String? ?? '',
        storeName: json['store_name'] as String? ?? '',
        storeLogoUrl: json['store_logo_url'] as String?,
        imageUrl: json['image_url'] as String?,
        quantity: json['quantity'] as int,
        stock: json['stock'] as int? ?? 99,
        unitPrice: (json['unit_price'] as num).toDouble(),
      );
}

class Cart {
  final String id;
  final String? tenantId;
  final List<CartItem> items;

  Cart({required this.id, required this.tenantId, required this.items});

  factory Cart.fromJson(Map<String, dynamic> json) => Cart(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String?,
        items: (json['items'] as List<dynamic>)
            .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  double get subtotal =>
      items.fold(0, (sum, item) => sum + item.unitPrice * item.quantity);
}

class OrderItem {
  final String productId;
  final String productNameSnapshot;
  final String? imageUrl;
  final double unitPrice;
  final int quantity;

  OrderItem({
    required this.productId,
    required this.productNameSnapshot,
    this.imageUrl,
    required this.unitPrice,
    required this.quantity,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        productId: json['product_id'] as String,
        productNameSnapshot: json['product_name_snapshot'] as String,
        imageUrl: json['image_url'] as String?,
        unitPrice: (json['unit_price'] as num).toDouble(),
        quantity: json['quantity'] as int,
      );
}

class Order {
  final String id;
  final String storeName;
  final String status;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.storeName,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        storeName: json['store_name'] as String? ?? '',
        status: json['status'] as String,
        subtotal: (json['subtotal'] as num).toDouble(),
        deliveryFee: (json['delivery_fee'] as num).toDouble(),
        total: (json['total'] as num).toDouble(),
        items: (json['items'] as List<dynamic>)
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

const Map<String, String> orderStatusLabels = {
  'PENDING': 'قيد الانتظار',
  'CONFIRMED': 'تم التأكيد',
  'PREPARING': 'قيد التجهيز',
  'READY': 'جاهز للاستلام',
  'OUT_FOR_DELIVERY': 'خرج للتوصيل',
  'DELIVERED': 'تم التوصيل',
  'CANCELLED': 'ملغي',
};
