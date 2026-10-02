import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';

String _slugify(String input) {
  final lower = input.trim().toLowerCase();
  return lower
      .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF\s-]'), '')
      .replaceAll(RegExp(r'\s+'), '-');
}

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Category> _categories = [];
  bool _loading = true;
  String? _error;
  final _nameController = TextEditingController();

  String? get _tenantId => context.read<AuthProvider>().tenantId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tenantId = _tenantId;
    if (tenantId == null) return;
    final res = await ApiClient.instance.get('/tenants/$tenantId/categories')
        as List<dynamic>;
    if (!mounted) return;
    setState(() {
      _categories =
          res.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
      _loading = false;
    });
  }

  Future<void> _add() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _error = null);
    try {
      await ApiClient.instance.post('/tenants/$_tenantId/categories', body: {
        'name': _nameController.text,
        'slug': _slugify(_nameController.text),
      });
      _nameController.clear();
      _load();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _delete(Category c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف التصنيف'),
        content: Text('هل تريد حذف تصنيف «${c.name}»؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('حذف', style: TextStyle(color: AppColors.rust))),
        ],
      ),
    );
    if (confirmed != true) return;
    await ApiClient.instance.delete('/tenants/$_tenantId/categories/${c.id}');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('التصنيفات',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text('نظّم المنتجات في تصنيفات ليسهل على العملاء العثور عليها',
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: _nameController,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                            hintText: 'اكتب اسم التصنيف الجديد'))),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('إضافة')),
              ],
            ),
          ),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style:
                        const TextStyle(color: AppColors.rust, fontSize: 12))),
          const SizedBox(height: 18),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _loading
                  ? const Center(
                      child: Text('جارٍ تحميل التصنيفات...',
                          style: TextStyle(color: AppColors.ash)))
                  : _categories.isEmpty
                      ? Text('لا توجد تصنيفات حتى الآن.',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant))
                      : Container(
                          decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              border: Border.all(color: AppColors.ashLight),
                              borderRadius: BorderRadius.circular(14)),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _categories.length,
                            separatorBuilder: (_, __) => const Divider(
                                height: 1, color: AppColors.ashLight),
                            itemBuilder: (context, i) {
                              final c = _categories[i];
                              return ListTile(
                                title: Text(c.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.5)),
                                subtitle: Text('/${c.slug}',
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.ash)),
                                trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 17),
                                    color: AppColors.rust,
                                    onPressed: () => _delete(c)),
                              );
                            },
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
