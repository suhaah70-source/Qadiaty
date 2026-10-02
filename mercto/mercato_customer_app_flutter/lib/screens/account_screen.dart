import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mercato/core/app_theme.dart';
import 'package:mercato/providers/auth_provider.dart';
import 'package:mercato/providers/theme_provider.dart';
import 'package:mercato/providers/language_provider.dart';
import 'package:mercato/screens/admin_dashboard_screen.dart';
import 'package:mercato/screens/login_screen.dart';
import 'package:mercato/screens/register_screen.dart';
import 'package:mercato/screens/store_application_screen.dart';
import 'package:mercato/screens/vendor_dashboard_screen.dart';
import 'package:mercato/screens/addresses_screen.dart';
import 'package:mercato/screens/orders_screen.dart';

String _tx(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

class AccountScreen extends StatelessWidget {
  final VoidCallback? onOrdersTap;
  const AccountScreen({super.key, this.onOrdersTap});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_tx(context, "تأكيد تسجيل الخروج", "Confirm logout")),
        content: Text(_tx(context, "هل أنت متأكد أنك تريد تسجيل الخروج؟",
            "Are you sure you want to log out?")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_tx(context, "إلغاء", "Cancel")),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              _tx(context, "تسجيل الخروج", "Log out"),
              style: TextStyle(color: AppColors.rust),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<ThemeProvider>();
    final language = context.watch<LanguageProvider>();
    return Directionality(
      textDirection: language.locale.languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        appBar:
            AppBar(title: Text(_tx(context, "الحساب", "Account")), actions: [
          IconButton(
              onPressed: () => appearance.setDarkMode(!appearance.isDark),
              icon: Icon(appearance.isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined))
        ]),
        body: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (!auth.isAuthenticated) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  const Icon(Icons.person_outline,
                      size: 64, color: AppColors.ashLight),
                  const SizedBox(height: 18),
                  Center(
                      child: Text(_tx(
                          context,
                          "سجّل دخولك وخود قضيتك من متاجرنا",
                          "Sign in to continue"))),
                  const SizedBox(height: 8),
                  Center(
                      child: Text(_tx(
                          context,
                          "أنشئ حسابًا جديدًا للوصول إلى جميع الميزات",
                          "Create an account to access all features"))),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: Text(_tx(context, "تسجيل الدخول", "Sign in")),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child:
                        Text(_tx(context, "إنشاء حساب جديد", "Create account")),
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: kInkGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: AppColors.brass,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.userName ?? _tx(context, "مستخدم", "User"),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              auth.phone ??
                                  _tx(context, "لم يتم تسجيل الدخول",
                                      "Not signed in"),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            _tx(context, 'نقاطي ومكافآتي',
                                'My points and rewards'),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(_tx(
                            context,
                            'لديك ${auth.loyaltyPoints.toStringAsFixed(0)} نقطة و ${auth.walletBalance.toStringAsFixed(2)} د.ل في محفظتك',
                            'You have ${auth.loyaltyPoints.toStringAsFixed(0)} points and LYD ${auth.walletBalance.toStringAsFixed(2)} in your wallet')),
                        if (auth.availableRewards > 0) ...[
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: () async {
                              try {
                                await context
                                    .read<AuthProvider>()
                                    .redeemReward();
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(_tx(
                                          context,
                                          'تعذر استبدال المكافأة. حاول مرة أخرى.',
                                          'Could not redeem the reward. Please try again.')),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.card_giftcard_outlined),
                            label: Text(_tx(
                                context, 'استبدال مكافأة', 'Redeem a reward')),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _MenuTile(
                  icon: Icons.receipt_long_outlined,
                  label: _tx(context, "طلباتي", "My orders"),
                  onTap: onOrdersTap ??
                      () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const OrdersScreen())),
                ),
                _MenuTile(
                  icon: Icons.location_on_outlined,
                  label: _tx(context, "عناويني", "My addresses"),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddressesScreen()),
                  ),
                ),
                if (auth.role == 'ADMIN')
                  _MenuTile(
                    icon: Icons.admin_panel_settings_outlined,
                    label: _tx(context, "لوحة تحكم المشرف", "Admin dashboard"),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminDashboardScreen(),
                      ),
                    ),
                  )
                else if (auth.role == 'VENDOR')
                  _MenuTile(
                    icon: Icons.storefront_outlined,
                    label: _tx(context, "لوحة تحكم المتجر", "Store dashboard"),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const VendorDashboardScreen(),
                      ),
                    ),
                  )
                else
                  _MenuTile(
                    icon: Icons.add_business_outlined,
                    label:
                        _tx(context, "طلب فتح متجر", "Apply to open a store"),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const StoreApplicationScreen(),
                      ),
                    ),
                  ),
                _MenuTile(
                  icon: Icons.help_outline,
                  label: _tx(context, "المساعدة والدعم", "Help & support"),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(_tx(context, 'اللغة', 'Language')),
                  trailing: DropdownButton<String>(
                    value: language.locale.languageCode,
                    items: const [
                      DropdownMenuItem(value: 'ar', child: Text('العربية')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (value) {
                      if (value != null) language.setLanguage(value);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: Text(_tx(context, "الوضع الداكن", "Dark mode")),
                  subtitle: Text(_tx(
                      context,
                      "فعّل الوضع الداكن لتجربة مريحة للعينين",
                      "Turn on dark mode for a more comfortable experience")),
                  value: appearance.isDark,
                  onChanged: appearance.setDarkMode,
                ),
                _MenuTile(
                  icon: Icons.logout,
                  label: _tx(context, "تسجيل الخروج", "Log out"),
                  color: AppColors.rust,
                  onTap: () => _confirmLogout(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor = color ?? Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon, color: tileColor, size: 22),
          title: Text(
            label,
            style: TextStyle(
              color: tileColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          trailing: Icon(Icons.chevron_left,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          onTap: onTap,
        ),
      ),
    );
  }
}
