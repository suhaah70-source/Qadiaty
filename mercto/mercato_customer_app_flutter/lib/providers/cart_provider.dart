import 'package:flutter/foundation.dart';
import 'package:mercato/core/api_client.dart';
import 'package:mercato/models/models.dart';

class CartProvider extends ChangeNotifier {
  Cart? _cart;
  bool _loading = false;

  Cart? get cart => _cart;
  bool get loading => _loading;
  int get itemCount =>
      _cart?.items.fold<int>(0, (total, item) => total + item.quantity) ?? 0;

  Future<void> loadCart() async {
    _loading = true;
    notifyListeners();
    try {
      final data =
          await ApiClient.instance.get('/cart') as Map<String, dynamic>;
      _cart = Cart.fromJson(data);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        _cart = null;
      } else {
        rethrow;
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Kept for callers that open a store page; the cart is platform-wide.
  Future<void> loadForTenant(String _) => loadCart();

  Future<void> addItem(
    String storeId,
    String productId,
    int quantity,
  ) async {
    final data = await ApiClient.instance.post(
      '/cart/items',
      body: {'product_id': productId, 'quantity': quantity},
    ) as Map<String, dynamic>;
    _cart = Cart.fromJson(data);
    notifyListeners();
  }

  Future<void> removeItem(String itemId) async {
    final data = await ApiClient.instance.delete('/cart/items/$itemId')
        as Map<String, dynamic>;
    _cart = Cart.fromJson(data);
    notifyListeners();
  }

  Future<void> updateQuantity(
      String itemId, String productId, int quantity) async {
    final data = await ApiClient.instance.patch(
      '/cart/items/$itemId',
      body: {'product_id': productId, 'quantity': quantity},
    ) as Map<String, dynamic>;
    _cart = Cart.fromJson(data);
    notifyListeners();
  }

  Future<List<Order>> checkout({
    required String addressId,
    Map<String, String> storeNotes = const {},
  }) async {
    final result = await ApiClient.instance.post(
      '/cart/checkout',
      body: {
        'address_id': addressId,
        'payment_method': 'CASH_ON_DELIVERY',
        'store_notes': storeNotes,
      },
    ) as Map<String, dynamic>;
    final orders = (result['orders'] as List<dynamic>)
        .map((row) => Order.fromJson(row as Map<String, dynamic>))
        .toList();
    _cart = null;
    notifyListeners();
    return orders;
  }

  void clear() {
    _cart = null;
    notifyListeners();
  }
}
