import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'overview_screen.dart';
import 'products_screen.dart';
import 'categories_screen.dart';
import 'orders_screen.dart';
import 'theme_editor_screen.dart';
import 'team_screen.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final Widget Function() builder;
  const _NavItem(this.label, this.icon, this.builder);
}

/// تنقل لوحة التاجر بين الملخص والمنتجات والتصنيفات والطلبات والإعدادات.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _selected = 0;

  late final List<_NavItem> _items = [
    _NavItem(
        'نظرة عامة', Icons.grid_view_rounded, () => const OverviewScreen()),
    _NavItem(
        'المنتجات', Icons.inventory_2_outlined, () => const ProductsScreen()),
    _NavItem('التصنيفات', Icons.account_tree_outlined,
        () => const CategoriesScreen()),
    _NavItem(
        'الطلبات', Icons.shopping_bag_outlined, () => const OrdersScreen()),
    _NavItem('تصميم المتجر', Icons.palette_outlined,
        () => const ThemeEditorScreen()),
    _NavItem('فريق العمل', Icons.people_outline, () => const TeamScreen()),
  ];

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final tenant = auth.activeTenant;
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        drawer: isWide
            ? null
            : Drawer(child: _buildSidebar(tenant?.name, tenant?.code)),
        appBar: isWide
            ? null
            : AppBar(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                title: Text(_items[_selected].label),
              ),
        body: SafeArea(
          child: Row(
            children: [
              Expanded(child: _items[_selected].builder()),
              if (isWide)
                SizedBox(
                    width: 250,
                    child: _buildSidebar(tenant?.name, tenant?.code)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(String? name, String? code) {
    return Container(
      color: AppColors.ink,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white12))),
            child: Stack(
              children: [
                const Positioned.fill(child: HeritagePattern(opacity: 0.05)),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: AppColors.brass,
                          borderRadius: BorderRadius.circular(9)),
                      child: const Icon(Icons.storefront,
                          color: AppColors.ink, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(name ?? 'متجري',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          Text(code ?? '',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final active = i == _selected;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: active ? AppColors.brass : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() => _selected = i);
                        if (Scaffold.of(context).isDrawerOpen) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                        child: Row(
                          children: [
                            Icon(_items[i].icon,
                                size: 18,
                                color: active ? Colors.white : Colors.white70),
                            const SizedBox(width: 10),
                            Text(_items[i].label,
                                style: TextStyle(
                                    color:
                                        active ? Colors.white : Colors.white70,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12))),
            width: double.infinity,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _logout,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 18, color: Colors.white70),
                      SizedBox(width: 10),
                      Text('تسجيل الخروج',
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
