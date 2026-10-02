import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../widgets/stat_card.dart';
import '../widgets/tenant_network_grid.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  bool _loading = true;
  String? _error;
  PlatformAnalytics? _analytics;
  List<Tenant> _tenants = [];

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
      final responses = await Future.wait([
        ApiClient.instance.get('/admin/analytics'),
        ApiClient.instance.get('/tenants'),
      ]);
      final analytics = responses[0];
      final tenants = responses[1];
      if (!mounted) return;
      setState(() {
        _analytics = analytics is Map<String, dynamic>
            ? PlatformAnalytics.fromJson(analytics)
            : null;
        _tenants = tenants is List
            ? tenants
                .whereType<Map<String, dynamic>>()
                .map(Tenant.fromJson)
                .toList()
            : [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'تعذر تحميل إحصائيات المنصة. حاول تحديث الصفحة.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final analytics = _analytics;
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 950;
      return SingleChildScrollView(
        padding: EdgeInsets.all(wide ? 28 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('لوحة المنصة',
                        style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink)),
                    SizedBox(height: 4),
                    Text('متابعة المتاجر والطلبات والمبيعات',
                        style: TextStyle(fontSize: 13, color: AppColors.ash)),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'تحديث الإحصائيات',
                onPressed: _loading ? null : _load,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded),
              ),
            ]),
            const SizedBox(height: 22),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 70),
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.ink)),
              )
            else if (_error != null)
              _ErrorPanel(message: _error!, onRetry: _load)
            else if (analytics != null) ...[
              _PlatformHero(analytics: analytics),
              const SizedBox(height: 18),
              GridView.count(
                crossAxisCount: wide ? 4 : (constraints.maxWidth > 560 ? 2 : 1),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: wide ? 1.8 : 2.5,
                children: [
                  StatCard(
                      label: 'كل المتاجر',
                      value: '${analytics.tenantsTotal}',
                      icon: Icons.storefront_outlined,
                      accent: StatAccent.brass),
                  StatCard(
                      label: 'المتاجر النشطة',
                      value: '${analytics.tenantsActive}',
                      icon: Icons.store_mall_directory_outlined,
                      accent: StatAccent.jade),
                  StatCard(
                      label: 'بانتظار المراجعة',
                      value: '${analytics.tenantsPending}',
                      icon: Icons.pending_actions_outlined,
                      accent: StatAccent.rust),
                  StatCard(
                      label: 'طلبات قيد المعالجة',
                      value: '${analytics.ordersPending}',
                      icon: Icons.shopping_bag_outlined,
                      accent: StatAccent.brass),
                ],
              ),
              const SizedBox(height: 18),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        flex: 3,
                        child: _PlatformRevenueChart(
                            months: analytics.revenueByMonth)),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _PlatformQuickStats(analytics: analytics),
                    ),
                  ],
                )
              else ...[
                _PlatformRevenueChart(months: analytics.revenueByMonth),
                const SizedBox(height: 16),
                _PlatformQuickStats(analytics: analytics),
              ],
              const SizedBox(height: 18),
              TenantNetworkGrid(tenants: _tenants),
            ],
          ],
        ),
      );
    });
  }
}

class _PlatformHero extends StatelessWidget {
  const _PlatformHero({required this.analytics});
  final PlatformAnalytics analytics;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: kInkGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: AppColors.ink.withValues(alpha: .18),
                blurRadius: 20,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Stack(children: [
          const Positioned.fill(child: HeritagePattern(opacity: .06)),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('إجمالي المبيعات المكتملة',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .7), fontSize: 13)),
            const SizedBox(height: 8),
            Text('${analytics.grossMerchandiseValue.toStringAsFixed(0)} د.ل',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 8, children: [
              _HeroTag(
                  icon: Icons.receipt_long_outlined,
                  label: '${analytics.ordersTotal} طلب'),
              _HeroTag(
                  icon: Icons.inventory_2_outlined,
                  label: '${analytics.catalogTotalProducts} منتج'),
              _HeroTag(
                  icon: Icons.pause_circle_outline,
                  label: '${analytics.tenantsSuspended} متجر موقوف'),
            ]),
          ]),
        ]),
      );
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: .13)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: AppColors.brassLight),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ]),
      );
}

class _PlatformRevenueChart extends StatelessWidget {
  const _PlatformRevenueChart({required this.months});
  final List<Map<String, dynamic>> months;

  @override
  Widget build(BuildContext context) => _AdminPanel(
        title: 'نمو المبيعات',
        subtitle: 'الإيرادات المكتملة خلال آخر 6 أشهر',
        child: months.isEmpty
            ? const SizedBox(
                height: 160,
                child: Center(
                    child: Text('لا توجد بيانات شهرية حتى الآن',
                        style: TextStyle(color: AppColors.ash))),
              )
            : SizedBox(
                height: 160,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: months.map((item) {
                    final value = (item['revenue'] as num? ?? 0).toDouble();
                    final maxValue = months.fold<double>(
                        0,
                        (max, month) => math.max(
                            max, (month['revenue'] as num? ?? 0).toDouble()));
                    final ratio = maxValue <= 0 ? 0.0 : value / maxValue;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (value > 0)
                              Text(value.toStringAsFixed(0),
                                  style: const TextStyle(
                                      fontSize: 9, color: AppColors.ash)),
                            const SizedBox(height: 5),
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: .15 + ratio * .85,
                                  child: Container(
                                    width: 28,
                                    decoration: BoxDecoration(
                                      color: ratio >= .99
                                          ? AppColors.ink
                                          : AppColors.brass
                                              .withValues(alpha: .7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('${item['month']}'.split('-').last,
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

class _PlatformQuickStats extends StatelessWidget {
  const _PlatformQuickStats({required this.analytics});
  final PlatformAnalytics analytics;

  @override
  Widget build(BuildContext context) => _AdminPanel(
        title: 'ملخص المنصة',
        subtitle: 'مؤشرات التشغيل الحالية',
        child: Column(children: [
          _QuickStat(
              icon: Icons.storefront_outlined,
              title: 'متاجر نشطة',
              value: analytics.tenantsActive,
              total: analytics.tenantsTotal,
              color: AppColors.jade),
          const SizedBox(height: 17),
          _QuickStat(
              icon: Icons.shopping_bag_outlined,
              title: 'طلبات قيد المعالجة',
              value: analytics.ordersPending,
              total: analytics.ordersTotal,
              color: AppColors.brass),
          const SizedBox(height: 17),
          _QuickStat(
              icon: Icons.description_outlined,
              title: 'العقود النشطة',
              value: analytics.contractsActive,
              total: analytics.tenantsTotal,
              color: AppColors.rust),
        ]),
      );
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({
    required this.icon,
    required this.title,
    required this.value,
    required this.total,
    required this.color,
  });
  final IconData icon;
  final String title;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 12))),
          Text('$value / $total',
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: total == 0 ? 0 : (value / total).clamp(0.0, 1.0),
            color: color,
            backgroundColor: AppColors.ashLight.withValues(alpha: .6),
          ),
        ),
      ]);
}

class _AdminPanel extends StatelessWidget {
  const _AdminPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        ]),
      );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ]),
      );
}
