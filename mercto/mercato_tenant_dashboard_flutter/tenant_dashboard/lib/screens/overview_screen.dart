import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../widgets/license_card.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _analytics = const {};
  List<Order> _orders = const [];

  Future<void> _load() async {
    final tenantId = context.read<AuthProvider>().tenantId;
    if (tenantId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final responses = await Future.wait([
        ApiClient.instance.get('/tenants/$tenantId/analytics'),
        ApiClient.instance.get('/tenants/$tenantId/orders'),
      ]);
      final rawAnalytics = responses[0];
      final rawOrders = responses[1];
      if (!mounted) return;
      setState(() {
        _analytics = rawAnalytics is Map<String, dynamic>
            ? rawAnalytics
            : <String, dynamic>{};
        _orders = rawOrders is List
            ? rawOrders
                .whereType<Map<String, dynamic>>()
                .map(Order.fromJson)
                .toList()
            : <Order>[];
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'تعذر تحميل بيانات المتجر. تحقق من الاتصال وحاول مرة ثانية.';
        });
      }
    }
  }

  Map<String, dynamic> get _orderStats {
    final raw = _analytics['orders'];
    if (raw is Map<String, dynamic>) return raw;
    return {
      'total': _analytics['orders_total'] ?? 0,
      'pending': _analytics['pending_orders'] ?? 0,
      'gross_merchandise_value': _analytics['sales'] ?? 0,
    };
  }

  List<Map<String, dynamic>> get _monthlyRevenue {
    final raw = _analytics['revenue_by_month'];
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final tenant = context.watch<AuthProvider>().activeTenant;
    final orderStats = _orderStats;
    final catalog = _analytics['catalog'];
    final productCount = catalog is Map<String, dynamic>
        ? catalog['total_products'] ?? 0
        : _analytics['products'] ?? 0;
    final revenue =
        (orderStats['gross_merchandise_value'] as num? ?? 0).toDouble();
    final pending = (orderStats['pending'] as num? ?? 0).toInt();
    final totalOrders = (orderStats['total'] as num? ?? 0).toInt();
    final date = DateFormat('EEEE، d MMMM yyyy', 'ar').format(DateTime.now());

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 980;
      return SingleChildScrollView(
        padding: EdgeInsets.all(wide ? 28 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PageHeader(
              storeName: tenant?.name ?? 'متجرك',
              date: date,
              onRefresh: _load,
              loading: _loading,
            ),
            if (tenant != null) ...[
              const SizedBox(height: 18),
              LicenseCard(tenant: tenant),
            ],
            const SizedBox(height: 22),
            if (_loading)
              const _LoadingPanel()
            else if (_error != null)
              _ErrorPanel(message: _error!, onRetry: _load)
            else ...[
              GridView.count(
                crossAxisCount:
                    wide ? 4 : (constraints.maxWidth >= 560 ? 2 : 1),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: wide ? 1.75 : 2.45,
                children: [
                  _MetricCard(
                    label: 'إجمالي المبيعات',
                    value: '${revenue.toStringAsFixed(0)} د.ل',
                    note: 'من الطلبات المكتملة',
                    icon: Icons.account_balance_wallet_outlined,
                    color: AppColors.ink,
                    featured: true,
                  ),
                  _MetricCard(
                    label: 'الطلبات',
                    value: '$totalOrders',
                    note: '$pending طلب قيد التجهيز',
                    icon: Icons.shopping_bag_outlined,
                    color: AppColors.jade,
                  ),
                  _MetricCard(
                    label: 'منتجات المتجر',
                    value: '$productCount',
                    note: 'ضمن كتالوج متجرك',
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.brass,
                  ),
                  _MetricCard(
                    label: 'تحتاج متابعة',
                    value: '$pending',
                    note: pending == 0 ? 'كل الطلبات محدثة' : 'طلبات بانتظارك',
                    icon: Icons.notifications_active_outlined,
                    color: pending == 0 ? AppColors.jade : AppColors.rust,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _RevenuePanel(months: _monthlyRevenue),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _OrderStatusPanel(orders: _orders),
                    ),
                  ],
                )
              else ...[
                _RevenuePanel(months: _monthlyRevenue),
                const SizedBox(height: 16),
                _OrderStatusPanel(orders: _orders),
              ],
              const SizedBox(height: 18),
              _RecentOrdersPanel(orders: _orders.take(5).toList()),
            ],
          ],
        ),
      );
    });
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.storeName,
    required this.date,
    required this.onRefresh,
    required this.loading,
  });

  final String storeName;
  final String date;
  final VoidCallback onRefresh;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('نظرة عامة',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      )),
              const SizedBox(height: 4),
              Text('أهلاً بك في $storeName  •  $date',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'تحديث البيانات',
          onPressed: loading ? null : onRefresh,
          icon: loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.color,
    this.featured = false,
  });

  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color color;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final foreground = featured ? Colors.white : AppColors.ink;
    final muted = featured ? Colors.white70 : AppColors.ash;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: featured ? color : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: featured ? null : Border.all(color: AppColors.ashLight),
        boxShadow: featured
            ? [
                BoxShadow(
                    color: color.withValues(alpha: 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 8))
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: muted)),
              ),
              Icon(icon, color: featured ? Colors.white : color, size: 21),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 25,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: foreground)),
              const SizedBox(height: 5),
              Text(note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel(
      {required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.ashLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            const SizedBox(height: 3),
            Text(subtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.ash)),
            const SizedBox(height: 20),
            child,
          ],
        ),
      );
}

class _RevenuePanel extends StatelessWidget {
  const _RevenuePanel({required this.months});
  final List<Map<String, dynamic>> months;

  @override
  Widget build(BuildContext context) => _Panel(
        title: 'حركة المبيعات',
        subtitle: 'المبيعات المكتملة خلال آخر 6 أشهر',
        child: months.isEmpty
            ? const SizedBox(
                height: 170,
                child: Center(
                    child: Text('سيظهر الرسم بعد تسجيل المبيعات',
                        style: TextStyle(color: AppColors.ash))),
              )
            : SizedBox(
                height: 170,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: months.map((entry) {
                    final amount = (entry['revenue'] as num? ?? 0).toDouble();
                    final maxAmount = months.fold<double>(
                        0,
                        (maximum, item) => math.max(maximum,
                            (item['revenue'] as num? ?? 0).toDouble()));
                    final ratio = maxAmount == 0 ? 0.0 : amount / maxAmount;
                    final month = DateTime.tryParse('${entry['month']}-01');
                    final label = month == null
                        ? ''
                        : DateFormat('MMM', 'ar').format(month);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (amount > 0)
                              Text(amount.toStringAsFixed(0),
                                  style: const TextStyle(
                                      fontSize: 9, color: AppColors.ash)),
                            const SizedBox(height: 5),
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: 0.18 + ratio * 0.82,
                                  child: Container(
                                    width: 26,
                                    decoration: BoxDecoration(
                                      color: ratio >= 0.99
                                          ? AppColors.ink
                                          : AppColors.brass
                                              .withValues(alpha: 0.68),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(label,
                                style: const TextStyle(
                                    fontSize: 10, color: AppColors.ash)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
      );
}

class _OrderStatusPanel extends StatelessWidget {
  const _OrderStatusPanel({required this.orders});
  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    final pending = orders.where((order) => order.status == 'PENDING').length;
    final done = orders.where((order) => order.status == 'DELIVERED').length;
    final other = orders.length - pending - done;
    final total = math.max(orders.length, 1);
    return _Panel(
      title: 'حالة الطلبات',
      subtitle: 'توزيع الطلبات المسجلة في متجرك',
      child: orders.isEmpty
          ? const SizedBox(
              height: 110,
              child: Center(
                  child: Text('لا توجد طلبات حتى الآن',
                      style: TextStyle(color: AppColors.ash))),
            )
          : Column(
              children: [
                _StatusLine(
                    label: 'قيد المراجعة',
                    count: pending,
                    total: total,
                    color: AppColors.brass),
                const SizedBox(height: 16),
                _StatusLine(
                    label: 'تم التوصيل',
                    count: done,
                    total: total,
                    color: AppColors.jade),
                const SizedBox(height: 16),
                _StatusLine(
                    label: 'حالات أخرى',
                    count: other,
                    total: total,
                    color: AppColors.rust),
              ],
            ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 12))),
              Text('$count',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: count / total,
              color: color,
              backgroundColor: AppColors.ashLight.withValues(alpha: 0.6),
            ),
          ),
        ],
      );
}

class _RecentOrdersPanel extends StatelessWidget {
  const _RecentOrdersPanel({required this.orders});
  final List<Order> orders;

  @override
  Widget build(BuildContext context) => _Panel(
        title: 'أحدث الطلبات',
        subtitle: 'آخر الطلبات التي وصلت إلى متجرك',
        child: orders.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('ستظهر الطلبات الجديدة هنا',
                    style: TextStyle(color: AppColors.ash)),
              )
            : Column(
                children: [
                  for (var index = 0; index < orders.length; index++) ...[
                    _OrderRow(order: orders[index]),
                    if (index < orders.length - 1)
                      const Divider(height: 20, color: AppColors.ashLight),
                  ],
                ],
              ),
      );
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (order.status) {
      'PENDING' => AppColors.brass,
      'DELIVERED' => AppColors.jade,
      'CANCELLED' => AppColors.rust,
      _ => AppColors.ash,
    };
    final statusLabel = switch (order.status) {
      'PENDING' => 'قيد المراجعة',
      'CONFIRMED' => 'تم التأكيد',
      'PREPARING' => 'قيد التجهيز',
      'READY' => 'جاهز',
      'OUT_FOR_DELIVERY' => 'في الطريق',
      'DELIVERED' => 'تم التوصيل',
      'CANCELLED' => 'ملغي',
      _ => order.status,
    };
    final date = order.createdAt == null
        ? '—'
        : DateFormat('d MMM، HH:mm', 'ar').format(order.createdAt!.toLocal());
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: AppColors.canvas, borderRadius: BorderRadius.circular(11)),
          child: const Icon(Icons.receipt_long_outlined,
              size: 19, color: AppColors.ink),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'طلب #${order.id.substring(0, math.min(8, order.id.length))}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              Text('${order.items.length} منتجات  •  $date',
                  style: const TextStyle(fontSize: 10, color: AppColors.ash)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${order.total.toStringAsFixed(0)} د.ل',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            Text(statusLabel,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor)),
          ],
        ),
      ],
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
            child: CircularProgressIndicator(
                color: AppColors.ink, strokeWidth: 2)),
      );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_outlined,
                  color: AppColors.ash, size: 34),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
}
