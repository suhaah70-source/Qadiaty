import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/phone_utils.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  List<TeamMember> _members = [];
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
    final res = await ApiClient.instance.get('/tenants/$tenantId/team')
        as List<dynamic>;
    if (!mounted) return;
    setState(() {
      _members = res
          .map((e) => TeamMember.fromJson(e as Map<String, dynamic>))
          .toList();
      _loading = false;
    });
  }

  Future<void> _remove(TeamMember m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إزالة عضو'),
        content: Text('هل تريد إزالة «${m.name}» من فريق العمل؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('إزالة', style: TextStyle(color: AppColors.rust))),
        ],
      ),
    );
    if (confirmed != true) return;
    await ApiClient.instance.delete('/tenants/$_tenantId/team/${m.id}');
    _load();
  }

  void _openInvite() {
    showDialog(
      context: context,
      builder: (_) => _InviteDialog(tenantId: _tenantId!, onInvited: _load),
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
                    Text('فريق العمل',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface)),
                    Text('أضف أعضاء لمساعدتك في إدارة المتجر',
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                  onPressed: _openInvite,
                  icon: const Icon(Icons.person_add_alt, size: 17),
                  label: const Text('إضافة عضو')),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _loading
                ? Center(
                    child: Text('جارٍ تحميل الفريق...',
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
                      itemCount: _members.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.ashLight),
                      itemBuilder: (context, i) {
                        final m = _members[i];
                        final isOwner = m.role == 'OWNER_TENANT';
                        return ListTile(
                          title: Text(m.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13.5)),
                          subtitle: Text(m.email,
                              style: const TextStyle(
                                  fontSize: 11.5, color: AppColors.ash)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                    color:
                                        AppColors.brass.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6)),
                                child: Text(isOwner ? 'مالك المتجر' : 'مدير',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.brass,
                                        fontWeight: FontWeight.w600)),
                              ),
                              if (!isOwner)
                                IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 17),
                                    color: AppColors.rust,
                                    onPressed: () => _remove(m)),
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

class _InviteDialog extends StatefulWidget {
  final String tenantId;
  final VoidCallback onInvited;
  const _InviteDialog({required this.tenantId, required this.onInvited});

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _saving = false;

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ApiClient.instance.post('/tenants/${widget.tenantId}/team', body: {
        'name': _name.text,
        'phone': normalizeLibyanPhone(_email.text),
        'password': _password.text,
        'role': 'ADMIN_TENANT',
      });
      widget.onInvited();
      if (mounted) Navigator.pop(context);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة عضو للفريق'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
                controller: _name,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(labelText: 'الاسم')),
            const SizedBox(height: 10),
            TextField(
                controller: _email,
                decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    prefixIcon: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('🇱🇾'),
                          SizedBox(width: 6),
                          Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text('+218'))
                        ]))),
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left),
            const SizedBox(height: 10),
            TextField(
                controller: _password,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(labelText: 'كلمة المرور'),
                obscureText: true),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: AppColors.rust, fontSize: 12))),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء')),
        ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'جارٍ الحفظ...' : 'إضافة')),
      ],
    );
  }
}
