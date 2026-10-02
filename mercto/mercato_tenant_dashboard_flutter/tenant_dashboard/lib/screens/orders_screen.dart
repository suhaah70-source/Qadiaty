import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';

const _orderStatusColors = {
  'PENDING': AppColors.brass,
  'CONFIRMED': AppColors.jade,
  'PREPARING': AppColors.jade,
  'READY': AppColors.jade,
  'OUT_FOR_DELIVERY': AppColors.jade,
  'DELIVERED': AppColors.ash,
  'CANCELLED': AppColors.rust,
};

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order> _orders = [];
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
    final res = await ApiClient.instance.get('/tenants/$tenantId/orders')
        as List<dynamic>;
    if (!mounted) return;
    setState(() {
      _orders =
          res.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
      _loading = false;
    });
  }

  Future<void> _updateStatus(Order order, String status) async {
    await ApiClient.instance.patch(
        '/tenants/$_tenantId/orders/${order.id}/status',
        body: {'status': status});
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الطلبات',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text('${_orders.length} طلب',
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          Expanded(
            child: _loading
                ? const Center(
                    child: Text('جارٍ تحميل الطلبات...',
                        style: TextStyle(color: AppColors.ash)))
                : _orders.isEmpty
                    ? Center(
                        child: Text('لا توجد طلبات حاليًا.',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)))
                    : Container(
                        decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            border: Border.all(color: AppColors.ashLight),
                            borderRadius: BorderRadius.circular(14)),
                        child: ListView.separated(
                          itemCount: _orders.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 1, color: AppColors.ashLight),
                          itemBuilder: (context, i) {
                            final o = _orders[i];
                            final color =
                                _orderStatusColors[o.status] ?? AppColors.ash;
                            final canAdvance = o.status != 'DELIVERED' &&
                                o.status != 'CANCELLED';
                            final currentIndex =
                                kOrderStatusFlow.indexOf(o.status);
                            final nextStatus = (canAdvance &&
                                    currentIndex >= 0 &&
                                    currentIndex + 1 < kOrderStatusFlow.length)
                                ? kOrderStatusFlow[currentIndex + 1]
                                : null;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '#${o.id.substring(0, o.id.length > 8 ? 8 : o.id.length)}',
                                            style: const TextStyle(
                                                fontSize: 11.5,
                                                color: AppColors.ash)),
                                        Text(
                                            '${o.items.length} منتجات · ${o.total.toStringAsFixed(0)} د.ل',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13)),
                                        if ((o.customerNote ?? '').isNotEmpty)
                                          Text(
                                              'ملاحظة الزبون: ${o.customerNote}',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.ash)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 5),
                                    decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6)),
                                    child: Text(
                                        kOrderStatusLabels[o.status] ??
                                            o.status,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: color,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(width: 8),
                                  if (canAdvance)
                                    Wrap(spacing: 6, children: [
                                      if (nextStatus != null)
                                        TextButton(
                                          onPressed: () =>
                                              _updateStatus(o, nextStatus),
                                          style: TextButton.styleFrom(
                                              backgroundColor: AppColors.ink,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6)),
                                          child: Text(
                                              kOrderStatusLabels[nextStatus] ??
                                                  nextStatus,
                                              style: const TextStyle(
                                                  fontSize: 11)),
                                        ),
                                      TextButton(
                                        onPressed: () =>
                                            _updateStatus(o, 'CANCELLED'),
                                        style: TextButton.styleFrom(
                                            foregroundColor: AppColors.rust,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 6)),
                                        child: const Text('حفظ',
                                            style: TextStyle(fontSize: 11)),
                                      ),
                                    ]),
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
