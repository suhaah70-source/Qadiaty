import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/phone_utils.dart';
import '../models/models.dart';

const _statusColors = {
  'PENDING': AppColors.brass,
  'ACTIVE': AppColors.jade,
  'SUSPENDED': AppColors.rust,
  'CLOSED': AppColors.ash,
};

String _slugify(String input) {
  final lower = input.trim().toLowerCase();
  return lower
      .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF\s-]'), '')
      .replaceAll(RegExp(r'\s+'), '-');
}

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  List<Tenant> _tenants = [];
  List<Plan> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final t = await ApiClient.instance.get('/tenants') as List<dynamic>;
    final p = await ApiClient.instance.get('/plans') as List<dynamic>;
    if (!mounted) return;
    setState(() {
      _tenants =
          t.map((e) => Tenant.fromJson(e as Map<String, dynamic>)).toList();
      _plans = p.map((e) => Plan.fromJson(e as Map<String, dynamic>)).toList();
      _loading = false;
    });
  }

  Future<void> _toggleStatus(Tenant tenant) async {
    final newStatus = tenant.status == 'SUSPENDED' ? 'ACTIVE' : 'SUSPENDED';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
            newStatus == 'SUSPENDED' ? 'إيقاف المتجر' : 'إعادة تفعيل المتجر'),
        content: Text(newStatus == 'SUSPENDED'
            ? 'هل تريد إيقاف هذا المتجر مؤقتًا؟'
            : 'هل تريد إعادة تفعيل هذا المتجر؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('متابعة')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ApiClient.instance
        .patch('/tenants/${tenant.id}/status', body: {'status': newStatus});
    _load();
  }

  Future<void> _approve(Tenant tenant) async {
    try {
      await ApiClient.instance
          .patch('/tenants/${tenant.id}/status', body: {'status': 'ACTIVE'});
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  void _openCreate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateTenantSheet(plans: _plans, onCreated: _load),
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
                    Text('المتاجر',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface)),
                    Text('${_tenants.length} متجر مسجل',
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
                  label: const Text('إضافة متجر')),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _loading
                ? Center(
                    child: Text('جارٍ تحميل المتاجر...',
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
                      itemCount: _tenants.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.ashLight),
                      itemBuilder: (context, i) {
                        final t = _tenants[i];
                        final color = _statusColors[t.status] ?? AppColors.ash;
                        final suspended = t.status == 'SUSPENDED';
                        return ListTile(
                          title: Text(t.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13.5)),
                          subtitle: Text('${t.code} · /${t.slug}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontFamily: 'monospace')),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                    kTenantStatusLabels[t.status] ?? t.status,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: color,
                                        fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 6),
                              if (t.status == 'PENDING')
                                TextButton.icon(
                                  onPressed: () => _approve(t),
                                  icon: const Icon(Icons.check_circle_outline,
                                      size: 15),
                                  label: const Text('اعتماد',
                                      style: TextStyle(fontSize: 11.5)),
                                  style: TextButton.styleFrom(
                                      foregroundColor: AppColors.jade),
                                )
                              else
                                TextButton.icon(
                                  onPressed: () => _toggleStatus(t),
                                  icon: Icon(
                                      suspended
                                          ? Icons.check_circle_outline
                                          : Icons.block,
                                      size: 15),
                                  label: Text(suspended ? 'تفعيل' : 'إيقاف',
                                      style: const TextStyle(fontSize: 11.5)),
                                  style: TextButton.styleFrom(
                                      foregroundColor: suspended
                                          ? AppColors.jade
                                          : AppColors.rust),
                                ),
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

class _CreateTenantSheet extends StatefulWidget {
  final List<Plan> plans;
  final VoidCallback onCreated;
  const _CreateTenantSheet({required this.plans, required this.onCreated});

  @override
  State<_CreateTenantSheet> createState() => _CreateTenantSheetState();
}

class _CreateTenantSheetState extends State<_CreateTenantSheet> {
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _ownerName = TextEditingController();
  final _ownerEmail = TextEditingController();
  final _city = TextEditingController();
  final _ownerPassword = TextEditingController();
  String? _planId;
  String? _error;
  bool _saving = false;

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final ownerPhone = normalizeLibyanPhone(_ownerEmail.text);
      await ApiClient.instance.post('/tenants', body: {
        'name': _name.text,
        'slug': _slug.text,
        'owner_name': _ownerName.text,
        'owner_email': ownerPhone,
        'city': _city.text.trim(),
        'owner_password': _ownerPassword.text,
        'plan_id': _planId,
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
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
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24))),
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Row(children: [
              const Expanded(
                  child: Text('إضافة متجر جديد',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700))),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 8),
            _label('اسم المتجر'),
            TextField(
                controller: _name,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                onChanged: (v) => _slug.text = _slugify(v)),
            const SizedBox(height: 12),
            _label('رابط المتجر (Slug)'),
            TextField(
                controller: _slug,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: const TextStyle(fontFamily: 'monospace')),
            const SizedBox(height: 12),
            _label('المدينة'),
            TextField(
                controller: _city,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right),
            const SizedBox(height: 12),
            _label('الباقة'),
            DropdownButtonFormField<String>(
              initialValue: _planId,
              hint: const Text('اختر باقة'),
              items: widget.plans
                  .map(
                      (p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                  .toList(),
              onChanged: (v) => setState(() => _planId = v),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 4),
            const Text('بيانات صاحب المتجر',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ash)),
            const SizedBox(height: 12),
            _label('اسم صاحب المتجر'),
            TextField(
                controller: _ownerName,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right),
            const SizedBox(height: 12),
            _label('رقم هاتف صاحب المتجر'),
            TextField(
              controller: _ownerEmail,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹]')),
                LengthLimitingTextInputFormatter(9),
              ],
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              decoration: const InputDecoration(
                hintText: 'رقم ليبي من 9 أرقام',
                prefixIcon: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('🇱🇾'),
                    SizedBox(width: 7),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text('+218'),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _label('كلمة المرور المؤقتة'),
            TextField(controller: _ownerPassword, obscureText: true),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(color: AppColors.rust, fontSize: 12)),
            ],
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'جارٍ إنشاء المتجر...' : 'إنشاء المتجر'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
