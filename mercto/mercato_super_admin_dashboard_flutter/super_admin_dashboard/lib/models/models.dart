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

class Plan {
  final String id;
  final String name;
  final int maxProducts;
  final int maxAdmins;
  final int storageLimitMb;

  Plan({
    required this.id,
    required this.name,
    required this.maxProducts,
    required this.maxAdmins,
    required this.storageLimitMb,
  });

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
        id: json['id'] as String,
        name: json['name'] as String,
        maxProducts: json['max_products'] as int,
        maxAdmins: json['max_admins'] as int,
        storageLimitMb: json['storage_limit_mb'] as int,
      );
}

class PlatformAnalytics {
  final int tenantsTotal;
  final int tenantsActive;
  final int tenantsSuspended;
  final int tenantsPending;
  final int contractsActive;
  final int catalogTotalProducts;
  final int ordersTotal;
  final int ordersPending;
  final double grossMerchandiseValue;
  final List<Map<String, dynamic>> revenueByMonth;

  PlatformAnalytics({
    required this.tenantsTotal,
    required this.tenantsActive,
    required this.tenantsSuspended,
    required this.tenantsPending,
    required this.contractsActive,
    required this.catalogTotalProducts,
    required this.ordersTotal,
    required this.ordersPending,
    required this.grossMerchandiseValue,
    required this.revenueByMonth,
  });

  factory PlatformAnalytics.fromJson(Map<String, dynamic> json) {
    final tenants = json['tenants'] is Map<String, dynamic>
        ? json['tenants'] as Map<String, dynamic>
        : <String, dynamic>{};
    final contracts = json['contracts'] is Map<String, dynamic>
        ? json['contracts'] as Map<String, dynamic>
        : <String, dynamic>{};
    final catalog = json['catalog'] is Map<String, dynamic>
        ? json['catalog'] as Map<String, dynamic>
        : <String, dynamic>{};
    final orders = json['orders'] is Map<String, dynamic>
        ? json['orders'] as Map<String, dynamic>
        : <String, dynamic>{};
    int readInt(String key, Map<String, dynamic> nested, String nestedKey) =>
        ((json[key] ?? nested[nestedKey]) as num?)?.toInt() ?? 0;
    final rawRevenue = json['revenue_by_month'];
    return PlatformAnalytics(
      tenantsTotal: readInt('tenants_total', tenants, 'total'),
      tenantsActive: readInt('tenants_active', tenants, 'active'),
      tenantsSuspended: readInt('tenants_suspended', tenants, 'suspended'),
      tenantsPending: readInt('tenants_pending', tenants, 'pending'),
      contractsActive: readInt('contracts_active', contracts, 'active'),
      catalogTotalProducts:
          readInt('catalog_total_products', catalog, 'total_products'),
      ordersTotal: readInt('orders_total', orders, 'total'),
      ordersPending: readInt('orders_pending', orders, 'pending'),
      grossMerchandiseValue: ((json['gross_merchandise_value'] ??
                  orders['gross_merchandise_value']) as num?)
              ?.toDouble() ??
          0,
      revenueByMonth: rawRevenue is List
          ? rawRevenue.whereType<Map<String, dynamic>>().toList()
          : const [],
    );
  }
}

const kTenantStatusLabels = {
  'PENDING': 'قيد المراجعة',
  'ACTIVE': 'نشط',
  'SUSPENDED': 'موقوف',
  'CLOSED': 'مغلق',
};
