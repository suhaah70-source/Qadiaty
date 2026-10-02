import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/input_utils.dart';
import '../core/app_theme.dart';
import '../models/models.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  List<Plan> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiClient.instance.get('/plans') as List<dynamic>;
    if (!mounted) return;
    setState(() {
      _plans =
          res.map((e) => Plan.fromJson(e as Map<String, dynamic>)).toList();
      _loading = false;
    });
  }

  void _openCreate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePlanSheet(onCreated: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الباقات',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface)),
                    Text(
                        'حدّد عدد المنتجات والمستخدمين ومساحة التخزين لكل باقة',
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                  onPressed: _openCreate,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('إضافة باقة')),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _loading
                ? Center(
                    child: Text('جارٍ تحميل الباقات...',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)))
                : LayoutBuilder(builder: (context, constraints) {
                    final cols = constraints.maxWidth > 700 ? 3 : 1;
                    return GridView.count(
                      crossAxisCount: cols,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 1.35,
                      children: _plans.map((p) => _PlanCard(plan: p)).toList(),
                    );
                  }),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Plan plan;
  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: AppColors.ashLight),
          borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan.name,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 14),
          _row(context, 'الحد الأقصى للمنتجات', '${plan.maxProducts}'),
          _row(context, 'الحد الأقصى للمستخدمين', '${plan.maxAdmins}'),
          _row(context, 'مساحة التخزين',
              '${(plan.storageLimitMb / 1000).toStringAsFixed(1)} GB'),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            Text(value,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace')),
          ],
        ),
      );
}

class _CreatePlanSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreatePlanSheet({required this.onCreated});

  @override
  State<_CreatePlanSheet> createState() => _CreatePlanSheetState();
}

class _CreatePlanSheetState extends State<_CreatePlanSheet> {
  final _name = TextEditingController();
  final _maxProducts = TextEditingController(text: '100');
  final _maxAdmins = TextEditingController(text: '1');
  final _storageLimit = TextEditingController(text: '5000');
  String? _error;
  bool _saving = false;

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ApiClient.instance.post('/plans', body: {
        'name': _name.text,
        'max_products':
            int.tryParse(normalizeInputDigits(_maxProducts.text)) ?? 0,
        'max_admins': int.tryParse(normalizeInputDigits(_maxAdmins.text)) ?? 0,
        'storage_limit_mb':
            int.tryParse(normalizeInputDigits(_storageLimit.text)) ?? 0,
        'features_json': {},
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ash)),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Expanded(
                  child: Text('إضافة باقة جديدة',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700))),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 8),
            _label('اسم الباقة'),
            TextField(
                controller: _name,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right),
            const SizedBox(height: 12),
            _label('الحد الأقصى للمنتجات'),
            TextField(
                controller: _maxProducts, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _label('الحد الأقصى للمستخدمين'),
            TextField(
                controller: _maxAdmins, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _label('مساحة التخزين (ميغابايت)'),
            TextField(
                controller: _storageLimit, keyboardType: TextInputType.number),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(color: AppColors.rust, fontSize: 12)),
            ],
            const SizedBox(height: 18),
            ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الباقة')),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
