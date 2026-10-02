import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mercato/core/app_theme.dart';
import 'package:mercato/providers/cart_provider.dart';
import 'package:mercato/providers/auth_provider.dart';
import 'package:mercato/providers/location_provider.dart';
import 'package:mercato/screens/account_screen.dart';
import 'package:mercato/screens/cart_screen.dart';
import 'package:mercato/screens/favorites_screen.dart';
import 'package:mercato/screens/home_screen.dart';
import 'package:mercato/screens/orders_screen.dart';

String _tx(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

class MainShell extends StatefulWidget {
  final int initialTab;
  const MainShell({super.key, this.initialTab = 0});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialTab.clamp(0, 4);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<AuthProvider>().isAuthenticated) {
        unawaited(context.read<LocationProvider>().locate());
      }
    });
  }

  late final List<Widget> _screens = [
    const HomeScreen(),
    const FavoritesScreen(),
    const CartScreen(tenantId: '', accentColor: AppColors.burgundy),
    const OrdersScreen(embedded: true),
    AccountScreen(onOrdersTap: () => _select(3)),
  ];

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: Localizations.localeOf(context).languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: Scaffold(
          body: IndexedStack(index: _index, children: _screens),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              height: 78,
              margin: const EdgeInsets.fromLTRB(16, 5, 16, 8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: .98),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: .8)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: .13),
                    blurRadius: 22,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Row(children: [
                _NavItem(
                    icon: Icons.home_rounded,
                    label: _tx(context, 'الرئيسية', 'Home'),
                    selected: _index == 0,
                    onTap: () => _select(0)),
                _NavItem(
                    icon: Icons.favorite_rounded,
                    label: _tx(context, 'المفضلة', 'Favorites'),
                    selected: _index == 1,
                    onTap: () => _select(1)),
                Consumer<CartProvider>(
                  builder: (context, cart, _) => _NavItem(
                    icon: Icons.shopping_cart_rounded,
                    label: _tx(context, 'السلة', 'Cart'),
                    selected: _index == 2,
                    badge: cart.itemCount,
                    onTap: () => _select(2),
                  ),
                ),
                _NavItem(
                    icon: Icons.receipt_long_rounded,
                    label: _tx(context, 'الطلبات', 'Orders'),
                    selected: _index == 3,
                    onTap: () => _select(3)),
                _NavItem(
                    icon: Icons.menu_rounded,
                    label: _tx(context, 'حسابي', 'Account'),
                    selected: _index == 4,
                    onTap: () => _select(4)),
              ]),
            ),
          ),
        ),
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap,
      this.badge = 0});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: .62);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(clipBehavior: Clip.none, children: [
              Icon(icon, color: color, size: 23),
              if (badge > 0)
                Positioned(
                  top: -7,
                  right: -10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.burgundy,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    child: Text('$badge',
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 9)),
                  ),
                ),
            ]),
            const SizedBox(height: 3),
            Text(label,
                maxLines: 1,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            const SizedBox(height: 2),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: selected ? 1 : 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  width: selected ? 24 : 0,
                  height: 6,
                  child: const ColoredBox(color: AppColors.jade),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
