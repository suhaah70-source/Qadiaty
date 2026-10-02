import 'package:flutter/material.dart';
import 'package:mercato/core/api_client.dart';

String _tx(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

String _metricName(BuildContext context, String key) {
  const labels = <String, (String, String)>{
    'users': ('المستخدمون', 'Users'),
    'stores': ('المتاجر', 'Stores'),
    'pending_stores': ('متاجر بانتظار المراجعة', 'Pending stores'),
    'approved_stores': ('متاجر معتمدة', 'Approved stores'),
    'orders': ('الطلبات', 'Orders'),
    'revenue': ('الإيرادات', 'Revenue'),
  };
  final label = labels[key];
  return label == null ? key : _tx(context, label.$1, label.$2);
}

String _categoryName(BuildContext context, String key) {
  const labels = <String, (String, String)>{
    'clothing': ('ملابس', 'Clothing'),
    'shoes': ('أحذية', 'Shoes'),
    'pharmacy': ('صيدليات', 'Pharmacy'),
    'electronics': ('إلكترونيات', 'Electronics'),
    'home': ('المنزل', 'Home'),
    'beauty': ('الجمال والعناية', 'Beauty & care'),
    'grocery': ('مواد غذائية', 'Groceries'),
    'general': ('متجر عام', 'General store'),
  };
  final label = labels[key];
  return label == null ? key : _tx(context, label.$1, label.$2);
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic> _overview = {};
  List<dynamic> _applications = [];
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final response = await Future.wait([
        ApiClient.instance.get('/admin/overview'),
        ApiClient.instance.get('/admin/store-applications'),
      ]);
      if (!mounted) return;
      setState(() {
        _overview = response[0] as Map<String, dynamic>;
        _applications = response[1] as List<dynamic>;
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(String id, String status) async {
    try {
      await ApiClient.instance.patch('/admin/stores/$id/review',
          body: {'status': status});
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: Localizations.localeOf(context).languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(title: Text(_tx(context, 'لوحة تحكم الإدارة', 'Admin dashboard')), actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
          ]),
          body: _busy
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(_overview.entries
                                  .map((e) => '${_metricName(context, e.key)}: ${e.value}')
                                  .join('   •   ')),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(_tx(context, 'طلبات المتاجر', 'Store applications'),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 20)),
                          ),
                          if (_applications.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(_tx(context, 'لا توجد طلبات متاجر حالياً', 'There are no store applications right now')),
                            ),
                          ..._applications.map((entry) {
                            final item = entry as Map<String, dynamic>;
                            return Card(
                              child: ListTile(
                                title: Text(item['name']?.toString() ?? ''),
                                subtitle: Text(
                                    '${item['city'] ?? ''} • ${_categoryName(context, item['store_category']?.toString() ?? 'general')}'),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) =>
                                      _review(item['id'].toString(), value),
                                  itemBuilder: (menuContext) => [
                                    PopupMenuItem(
                                        value: 'APPROVED',
                                        child: Text(_tx(menuContext, 'موافقة', 'Approve'))),
                                    PopupMenuItem(
                                        value: 'REJECTED', child: Text(_tx(menuContext, 'رفض', 'Reject'))),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
        ),
      );
}
