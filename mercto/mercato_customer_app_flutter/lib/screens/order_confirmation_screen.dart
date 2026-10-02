import 'package:flutter/material.dart';
import 'package:mercato/models/models.dart';
import 'package:mercato/screens/main_shell.dart';

String _tx(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

class OrderConfirmationScreen extends StatelessWidget {
  final List<Order> orders;
  final Color accentColor;

  const OrderConfirmationScreen({
    super.key,
    required this.orders,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final total = orders.fold<double>(0, (sum, order) => sum + order.total);
    return Directionality(
      textDirection: Localizations.localeOf(context).languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: .1),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.check_rounded, color: accentColor, size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  _tx(context, 'تم تأكيد الطلب', 'Order confirmed'),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  orders.length == 1
                      ? _tx(context, 'تم إرسال طلبك إلى المتجر بنجاح.',
                          'Your order was sent to the store.')
                      : _tx(context, 'تم إرسال طلباتك إلى المتاجر بنجاح.',
                          'Your orders were sent to the stores.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                ...orders.map(
                  (order) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      '${_tx(context, 'رقم الطلب', 'Order')}: ${order.id}',
                      style: const TextStyle(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_tx(context, 'الإجمالي', 'Total')}: ${total.toStringAsFixed(2)} ${_tx(context, 'د.ل', 'LYD')}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const MainShell(initialTab: 3)),
                      (route) => false,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(_tx(context, 'عرض طلباتي', 'View my orders')),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainShell()),
                    (route) => false,
                  ),
                  child:
                      Text(_tx(context, 'العودة إلى الرئيسية', 'Back to home')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
