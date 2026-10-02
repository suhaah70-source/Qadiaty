import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mercato/core/api_client.dart';
import 'package:mercato/core/app_theme.dart';
import 'package:mercato/core/media_url.dart';
import 'package:mercato/models/models.dart';
import 'package:mercato/providers/auth_provider.dart';
import 'package:mercato/screens/login_screen.dart';
import 'package:mercato/screens/register_screen.dart';

String _tx(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

String _statusLabel(BuildContext context, String status) {
  const labels = <String, (String, String)>{
    'PENDING': ('قيد الانتظار', 'Pending'),
    'CONFIRMED': ('تم التأكيد', 'Confirmed'),
    'PREPARING': ('قيد التجهيز', 'Preparing'),
    'READY': ('جاهز للاستلام', 'Ready for pickup'),
    'OUT_FOR_DELIVERY': ('خرج للتوصيل', 'Out for delivery'),
    'DELIVERED': ('تم التوصيل', 'Delivered'),
    'CANCELLED': ('ملغي', 'Cancelled'),
  };
  final pair = labels[status];
  return pair == null ? status : _tx(context, pair.$1, pair.$2);
}

class OrdersScreen extends StatefulWidget {
  /// يعرض الطلبات داخل التبويب عند تفعيل embedded، وإلا يعرض شريط عنوان مستقل.
  final bool embedded;
  const OrdersScreen({super.key, this.embedded = false});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (!context.read<AuthProvider>().isAuthenticated) {
      _orders = [];
      _loading = false;
      _error = null;
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiClient.instance.get('/orders/me') as List<dynamic>;
      setState(() {
        _orders =
            data.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return AppColors.ash;
      case 'CANCELLED':
        return AppColors.rust;
      case 'CONFIRMED':
        return AppColors.brass;
      default:
        return AppColors.jade;
    }
  }

  Widget _orderProgress(String status) {
    const stages = <(String, IconData, String, String)>[
      ('PENDING', Icons.receipt_long_rounded, 'استلام', 'Received'),
      ('CONFIRMED', Icons.verified_rounded, 'تأكيد', 'Confirmed'),
      ('PREPARING', Icons.inventory_2_rounded, 'تجهيز', 'Preparing'),
      ('OUT_FOR_DELIVERY', Icons.local_shipping_rounded, 'توصيل', 'Shipping'),
      ('DELIVERED', Icons.home_rounded, 'وصل', 'Delivered'),
    ];
    final current = switch (status) {
      'PENDING' => 0,
      'CONFIRMED' => 1,
      'PREPARING' || 'READY' => 2,
      'OUT_FOR_DELIVERY' => 3,
      'DELIVERED' => 4,
      _ => -1,
    };
    if (current < 0) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < stages.length; i++) ...[
          Expanded(
            child: Column(children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= current ? AppColors.jade : AppColors.canvas,
                ),
                child: Icon(stages[i].$2,
                    size: 16,
                    color: i <= current ? Colors.white : AppColors.ash),
              ),
              const SizedBox(height: 5),
              Text(_tx(context, stages[i].$3, stages[i].$4),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 9,
                      color: i <= current ? AppColors.ink : AppColors.ash,
                      fontWeight:
                          i == current ? FontWeight.w700 : FontWeight.w500)),
            ]),
          ),
          if (i < stages.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: i < current ? AppColors.jade : AppColors.ashLight,
              ),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(onRefresh: _loadOrders, child: _buildBody());

    if (widget.embedded) {
      return Directionality(
        textDirection: Localizations.localeOf(context).languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(title: Text(_tx(context, 'طلباتي', 'My orders'))),
          body: body,
        ),
      );
    }

    return Directionality(
      textDirection: Localizations.localeOf(context).languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
          appBar: AppBar(title: Text(_tx(context, 'طلباتي', 'My orders'))),
          body: body),
    );
  }

  Widget _buildBody() {
    if (!context.read<AuthProvider>().isAuthenticated) {
      return ListView(
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 90),
          const Icon(Icons.receipt_long_outlined,
              size: 58, color: AppColors.ashLight),
          const SizedBox(height: 16),
          Center(
              child: Text(_tx(context, 'سجّل الدخول لمتابعة طلباتك',
                  'Sign in to view your orders'))),
          const SizedBox(height: 18),
          Center(
            child: Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: Text(_tx(context, 'تسجيل الدخول', 'Sign in')),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  child: Text(_tx(context, 'إنشاء حساب', 'Create account')),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.brass));
    }
    if (_error != null) {
      return ListView(
        children: [const SizedBox(height: 100), Center(child: Text(_error!))],
      );
    }
    if (_orders.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: 80),
          Icon(Icons.receipt_long_outlined,
              size: 56, color: AppColors.ashLight),
          SizedBox(height: 12),
          Center(
              child: Text(
                  _tx(context, 'لا توجد طلبات حتى الآن',
                      'You have no orders yet'),
                  style: TextStyle(color: AppColors.ash))),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        final color = _statusColor(order.status);
        final cancelled = order.status == 'CANCELLED';

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.ashLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${_tx(context, 'رقم الطلب', 'Order')}: ${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        _statusLabel(context, order.status),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: color,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: AppColors.ashLight),
                    ),
                    child: order.items.isNotEmpty &&
                            order.items.first.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.network(
                              mediaUrl(order.items.first.imageUrl)!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.inventory_2_outlined,
                                  color: AppColors.jade,
                                  size: 30),
                            ),
                          )
                        : const Icon(Icons.inventory_2_outlined,
                            color: AppColors.jade, size: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            order.items.isEmpty
                                ? _tx(context, 'طلب منتجات', 'Product order')
                                : order.items.first.productNameSnapshot,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        Text(
                            _tx(context, '${order.items.length} منتجات',
                                '${order.items.length} products'),
                            style:
                                TextStyle(color: AppColors.ash, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!cancelled) _orderProgress(order.status),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      _tx(context, 'المتجر: ${order.storeName}',
                          'Store: ${order.storeName}'),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13)),
                  Text(
                    _tx(context, '${order.total.toStringAsFixed(2)} د.ل',
                        'LYD ${order.total.toStringAsFixed(2)}'),
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
