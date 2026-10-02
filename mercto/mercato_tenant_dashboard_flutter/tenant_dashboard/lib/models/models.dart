class Tenant {
  final String id;
  final String code;
  final String slug;
  final String name;
  final String status; // PENDING | ACTIVE | SUSPENDED | CLOSED
  final String? logoUrl;

  Tenant({
    required this.id,
    required this.code,
    required this.slug,
    required this.name,
    required this.status,
    this.logoUrl,
  });

  factory Tenant.fromJson(Map<String, dynamic> json) => Tenant(
        id: json['id'] as String,
        code: json['code'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        status: json['status'] as String,
        logoUrl: json['logo_url'] as String?,
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
  final String? fontFamily;
  final String productImageShape;
  final double productImageScale;
  final String productLayout;
  final int productColumns;
  final String categoryStyle;
  final String productCardStyle;
  final bool showProductCard;
  final bool showProductDescriptions;
  final String storeCategory;
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
  final String storeName;
  final String storeDescription;
  final List<Map<String, dynamic>> designElements;

  StoreTheme({
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.textColor,
    this.logoUrl,
    this.bannerUrl,
    this.logoShape = 'circle',
    this.fontFamily,
    this.productImageShape = 'rounded',
    this.productImageScale = 0.85,
    this.productLayout = 'grid',
    this.productColumns = 2,
    this.categoryStyle = 'chips',
    this.productCardStyle = 'classic',
    this.showProductCard = true,
    this.showProductDescriptions = false,
    this.storeCategory = 'general',
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
    this.storeName = '',
    this.storeDescription = '',
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
        fontFamily: json['font_family'] as String?,
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
        storeCategory: json['store_category'] as String? ?? 'general',
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
        storeName: json['store_name'] as String? ?? '',
        storeDescription: json['store_description'] as String? ?? '',
        designElements: (json['design_elements'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(),
      );

  StoreTheme copyWith({
    String? primaryColor,
    String? secondaryColor,
    String? backgroundColor,
    String? textColor,
    String? logoUrl,
    String? bannerUrl,
    String? logoShape,
    String? productImageShape,
    double? productImageScale,
    String? productLayout,
    int? productColumns,
    String? categoryStyle,
    String? productCardStyle,
    bool? showProductCard,
    bool? showProductDescriptions,
    String? storeCategory,
    String? backgroundImageUrl,
    String? backgroundImageFit,
    double? backgroundOverlayOpacity,
    String? logoPosition,
    String? backgroundStyle,
    String? backgroundGradientStart,
    String? backgroundGradientEnd,
    String? accentColor,
    String? cardColor,
    double? controlsX,
    double? controlsY,
    String? storeName,
    String? storeDescription,
    List<Map<String, dynamic>>? designElements,
  }) =>
      StoreTheme(
        primaryColor: primaryColor ?? this.primaryColor,
        secondaryColor: secondaryColor ?? this.secondaryColor,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        textColor: textColor ?? this.textColor,
        logoUrl: logoUrl ?? this.logoUrl,
        bannerUrl: bannerUrl ?? this.bannerUrl,
        logoShape: logoShape ?? this.logoShape,
        fontFamily: fontFamily,
        productImageShape: productImageShape ?? this.productImageShape,
        productImageScale: productImageScale ?? this.productImageScale,
        productLayout: productLayout ?? this.productLayout,
        productColumns: productColumns ?? this.productColumns,
        categoryStyle: categoryStyle ?? this.categoryStyle,
        productCardStyle: productCardStyle ?? this.productCardStyle,
        showProductCard: showProductCard ?? this.showProductCard,
        showProductDescriptions:
            showProductDescriptions ?? this.showProductDescriptions,
        storeCategory: storeCategory ?? this.storeCategory,
        backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
        backgroundImageFit: backgroundImageFit ?? this.backgroundImageFit,
        backgroundOverlayOpacity:
            backgroundOverlayOpacity ?? this.backgroundOverlayOpacity,
        logoPosition: logoPosition ?? this.logoPosition,
        backgroundStyle: backgroundStyle ?? this.backgroundStyle,
        backgroundGradientStart:
            backgroundGradientStart ?? this.backgroundGradientStart,
        backgroundGradientEnd:
            backgroundGradientEnd ?? this.backgroundGradientEnd,
        accentColor: accentColor ?? this.accentColor,
        cardColor: cardColor ?? this.cardColor,
        controlsX: controlsX ?? this.controlsX,
        controlsY: controlsY ?? this.controlsY,
        storeName: storeName ?? this.storeName,
        storeDescription: storeDescription ?? this.storeDescription,
        designElements: designElements ?? this.designElements,
      );

  Map<String, dynamic> toJson() => {
        'primary_color': primaryColor,
        'secondary_color': secondaryColor,
        'background_color': backgroundColor,
        'text_color': textColor,
        'logo_url': logoUrl,
        'banner_url': bannerUrl,
        'logo_shape': logoShape,
        'product_image_shape': productImageShape,
        'product_image_scale': productImageScale,
        'product_layout': productLayout,
        'product_columns': productColumns,
        'category_style': categoryStyle,
        'product_card_style': productCardStyle,
        'show_product_card': showProductCard,
        'show_product_descriptions': showProductDescriptions,
        'store_category': storeCategory,
        'background_image_url': backgroundImageUrl,
        'background_image_fit': backgroundImageFit,
        'background_overlay_opacity': backgroundOverlayOpacity,
        'logo_position': logoPosition,
        'background_style': backgroundStyle,
        'background_gradient_start': backgroundGradientStart,
        'background_gradient_end': backgroundGradientEnd,
        'accent_color': accentColor,
        'card_color': cardColor,
        'controls_x': controlsX,
        'controls_y': controlsY,
        'store_name': storeName,
        'store_description': storeDescription,
        'design_elements': designElements,
      };
}

class Category {
  final String id;
  final String name;
  final String slug;
  final String status;

  Category(
      {required this.id,
      required this.name,
      required this.slug,
      this.status = 'ACTIVE'});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        status: json['status'] as String? ?? 'ACTIVE',
      );
}

class Product {
  final String id;
  final String name;
  final String? description;
  final double price;
  final int stock;
  final String sku;
  final String status; // DRAFT | ACTIVE | OUT_OF_STOCK | ARCHIVED
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

class OrderItem {
  final String productId;
  final String productNameSnapshot;
  final double unitPrice;
  final int quantity;

  OrderItem({
    required this.productId,
    required this.productNameSnapshot,
    required this.unitPrice,
    required this.quantity,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        productId: json['product_id'] as String,
        productNameSnapshot: json['product_name_snapshot'] as String,
        unitPrice: (json['unit_price'] as num).toDouble(),
        quantity: json['quantity'] as int,
      );
}

class Order {
  final String id;
  final String status;
  final String? customerNote;
  final DateTime? createdAt;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.status,
    this.customerNote,
    this.createdAt,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        status: json['status'] as String,
        customerNote: json['customer_note'] as String?,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
        subtotal: (json['subtotal'] as num).toDouble(),
        deliveryFee: (json['delivery_fee'] as num).toDouble(),
        total: (json['total'] as num).toDouble(),
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TeamMember {
  final String id;
  final String userId;
  final String role; // OWNER_TENANT | ADMIN_TENANT
  final String email;
  final String name;

  TeamMember({
    required this.id,
    required this.userId,
    required this.role,
    required this.email,
    required this.name,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        role: json['role'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
      );
}

/// ����� ����� ������ ������� ��� �� ������� — ��� ������ �������
/// �������� �� ���� React ����� ����� ���� ��� ���������.
const kProductStatusLabels = {
  'DRAFT': 'مسودة',
  'ACTIVE': 'متاح',
  'OUT_OF_STOCK': 'نفد من المخزون',
  'ARCHIVED': 'مؤرشف',
};

const kOrderStatusLabels = {
  'PENDING': 'قيد الانتظار',
  'CONFIRMED': 'مؤكد',
  'PREPARING': 'قيد التجهيز',
  'READY': 'جاهز',
  'OUT_FOR_DELIVERY': 'في الطريق',
  'DELIVERED': 'تم التوصيل',
  'CANCELLED': 'ملغي',
};

const kOrderStatusFlow = [
  'PENDING',
  'CONFIRMED',
  'PREPARING',
  'READY',
  'OUT_FOR_DELIVERY',
  'DELIVERED',
];

const kTenantStatusLabels = {
  'ACTIVE': 'نشط',
  'PENDING': 'قيد المراجعة',
  'SUSPENDED': 'موقوف',
  'CLOSED': 'مغلق',
};
