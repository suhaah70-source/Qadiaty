import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mercato/core/api_client.dart';
import 'package:mercato/core/app_theme.dart';
import 'package:mercato/core/media_url.dart';
import 'package:mercato/core/mercato_logo.dart';
import 'package:mercato/models/models.dart';
import 'package:mercato/providers/auth_provider.dart';
import 'package:mercato/screens/store_screen.dart';

String _tx(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Tenant> _stores = [];
  List<dynamic> _banners = [];
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'all';
  String _selectedCity = 'all';
  final _searchController = TextEditingController();
  final _bannerController = PageController();

  static const _categoryLabels = <String, (String, String)>{
    'all': ('كل المتاجر', 'All stores'),
    'clothing': ('ملابس', 'Clothing'),
    'shoes': ('أحذية', 'Shoes'),
    'grocery': ('مواد غذائية', 'Groceries'),
    'pharmacy': ('صيدليات', 'Pharmacy'),
    'electronics': ('إلكترونيات', 'Electronics'),
    'home': ('المنزل', 'Home'),
    'beauty': ('الجمال والعناية', 'Beauty & care'),
    'general': ('متاجر أخرى', 'General stores'),
  };

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores({String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final term = query?.trim() ?? '';
      final path = term.isEmpty
          ? '/stores'
          : '/stores?q=${Uri.encodeQueryComponent(term)}';
      final responses = await Future.wait<dynamic>([
        ApiClient.instance.get(path, auth: false),
        ApiClient.instance.get('/banners', auth: false),
      ]);
      final data = responses[0] as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _stores = data
            .map((e) => Tenant.fromJson(e as Map<String, dynamic>))
            .toList();
        _banners = responses[1] as List<dynamic>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final cities = _stores
        .map((store) => store.city)
        .whereType<String>()
        .where((city) => city.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final visibleStores = _stores
        .where((store) =>
            (_selectedCategory == 'all' ||
                store.storeCategory == _selectedCategory) &&
            (_selectedCity == 'all' || store.city == _selectedCity))
        .toList();
    return Directionality(
      textDirection: Localizations.localeOf(context).languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          foregroundColor: foreground,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const MercatoLogoMark(size: 30),
                const SizedBox(width: 7),
                Text(_tx(context, '', ''),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 3),
              Container(
                width: 82,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: kInkGradient,
                ),
              ),
            ],
          ),
          actions: [
            Consumer<AuthProvider>(
                builder: (context, auth, _) => Padding(
                      padding: const EdgeInsetsDirectional.only(end: 10),
                      child: Center(
                          child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24)),
                            icon: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: AppColors.jade,
                                size: 34),
                            title: Text(
                                _tx(context, 'محفظة النقاط', 'Points wallet')),
                            content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_tx(context, 'رصيد نقاطك',
                                      'Your points balance')),
                                  const SizedBox(height: 5),
                                  Text(
                                      '${auth.loyaltyPoints.toStringAsFixed(0)} ${_tx(context, 'نقطة', 'points')}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.jade)),
                                  const Divider(height: 24),
                                  Text(_tx(context, 'رصيد المحفظة النقدي',
                                      'Wallet cash balance')),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${auth.walletBalance.toStringAsFixed(2)} ${_tx(context, 'د.ل', 'LYD')}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                                ]),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: Text(_tx(context, 'إغلاق', 'Close')))
                            ],
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: AppColors.jade.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(24)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.account_balance_wallet_outlined,
                                size: 19, color: AppColors.jade),
                            const SizedBox(width: 5),
                            Text(auth.loyaltyPoints.toStringAsFixed(0),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink)),
                          ]),
                        ),
                      )),
                    )),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => _loadStores(query: _searchController.text),
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TextField(
                  controller: _searchController,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: foreground),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) => _loadStores(query: value),
                  decoration: InputDecoration(
                    hintText: _tx(context, 'ابحث عن متجر أو منتج',
                        'Search stores or products'),
                    hintStyle:
                        TextStyle(color: foreground.withValues(alpha: .6)),
                    prefixIcon: Icon(Icons.search,
                        color: foreground.withValues(alpha: .6)),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(children: [
                  SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _categoryLabels.entries
                            .map((entry) => Padding(
                                  padding:
                                      const EdgeInsetsDirectional.only(end: 8),
                                  child: ChoiceChip(
                                      showCheckmark: false,
                                      label: Text(
                                          Localizations.localeOf(context)
                                                      .languageCode ==
                                                  'ar'
                                              ? entry.value.$1
                                              : entry.value.$2),
                                      selected: _selectedCategory == entry.key,
                                      selectedColor: AppColors.jade,
                                      backgroundColor:
                                          Theme.of(context).colorScheme.surface,
                                      elevation: _selectedCategory == entry.key
                                          ? 2
                                          : 0,
                                      labelStyle: TextStyle(
                                        color: _selectedCategory == entry.key
                                            ? Colors.white
                                            : foreground,
                                        fontWeight:
                                            _selectedCategory == entry.key
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                      ),
                                      onSelected: (_) => setState(
                                          () => _selectedCategory = entry.key)),
                                ))
                            .toList(),
                      )),
                  if (cities.length > 1)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: DropdownButton<String>(
                          value: _selectedCity,
                          hint: Text(_tx(context, 'كل المدن', 'All cities')),
                          items: [
                            DropdownMenuItem(
                                value: 'all',
                                child: Text(
                                    _tx(context, 'كل المدن', 'All cities'))),
                            ...cities.map((city) => DropdownMenuItem(
                                value: city, child: Text(city)))
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedCity = value ?? 'all')),
                    ),
                ]),
              ),
            ),
            if (_banners.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 150,
                  child: PageView.builder(
                    controller: _bannerController,
                    itemCount: _banners.length,
                    itemBuilder: (context, index) {
                      final banner = _banners[index] as Map<String, dynamic>;
                      final image = mediaUrl(banner['image_url'] as String?);
                      return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: MediaQuery.sizeOf(context).width - 52,
                              color: AppColors.ink,
                              child: Stack(fit: StackFit.expand, children: [
                                if (image != null)
                                  Image.network(image,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox()),
                                Align(
                                  alignment: AlignmentDirectional.bottomStart,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    color: Colors.black.withValues(alpha: .42),
                                    child: Text(
                                        banner['title'] as String? ??
                                            _tx(context, 'عروض مميزة',
                                                'Featured offers'),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ]),
                            ),
                          ));
                    },
                  ),
                ),
              ),
            if (_loading)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              SliverFillRemaining(
                  child: Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!,
                              style: TextStyle(color: foreground),
                              textAlign: TextAlign.center))))
            else if (visibleStores.isEmpty)
              SliverFillRemaining(
                  child: Center(
                      child: Text(
                          _tx(context, 'لا توجد متاجر تطابق بحثك حاليًا',
                              'No stores match your search right now'),
                          style: TextStyle(
                              color: foreground.withValues(alpha: .7)))))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                  (context, index) => _StoreCard(store: visibleStores[index]),
                  childCount: visibleStores.length,
                )),
              ),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bannerController.dispose();
    super.dispose();
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store});
  final Tenant store;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final banner = mediaUrl(store.bannerUrl);
    final logo = mediaUrl(store.logoUrl);
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => StoreScreen(slug: store.slug))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              height: 190,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24),
                image: banner == null
                    ? null
                    : DecorationImage(
                        image: NetworkImage(banner),
                        fit: BoxFit.cover,
                        onError: (_, __) {}),
              ),
              child: banner == null
                  ? Center(
                      child: Icon(Icons.storefront,
                          size: 64, color: foreground.withValues(alpha: .6)))
                  : null,
            ),
            Positioned(
              bottom: -13,
              left: 18,
              child: ClipPath(
                clipper: _StoreLogoShapeClipper(store.logoShape),
                child: Container(
                  width: 76,
                  height: 76,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      border: Border.all(color: Colors.white70, width: 2)),
                  child: logo == null
                      ? Container(
                          color: dark ? AppColors.ink : Colors.white,
                          child: const Icon(Icons.storefront,
                              color: AppColors.jade, size: 32))
                      : Image.network(logo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.storefront,
                              color: Colors.white)),
                ),
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: AppColors.darkGreen.withValues(alpha: .88),
                    borderRadius: BorderRadius.circular(30)),
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.verified,
                          size: 17, color: AppColors.dustyBlue),
                      SizedBox(width: 6),
                      Text(
                          _tx(context, "اكتشف متاجر ومنتجات قريبة منك",
                              "Discover nearby stores and products"),
                          style: TextStyle(color: Colors.white, fontSize: 13))
                    ])),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 24, 4, 0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ((store.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(store.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: foreground.withValues(alpha: .74),
                        fontSize: 14,
                        height: 1.4)),
              ],
              if ((store.city ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.location_on_outlined,
                      size: 17, color: foreground.withValues(alpha: .65)),
                  const SizedBox(width: 4),
                  Text(store.city!,
                      style: TextStyle(
                          color: foreground.withValues(alpha: .65),
                          fontSize: 13))
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _StoreLogoShapeClipper extends CustomClipper<Path> {
  const _StoreLogoShapeClipper(this.shape);
  final String shape;

  @override
  Path getClip(Size size) {
    if (shape == 'circle') return Path()..addOval(Offset.zero & size);
    if (shape == 'triangle') {
      return Path()
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    }
    if (shape == 'diamond') {
      return Path()
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(0, size.height / 2)
        ..close();
    }
    if (shape == 'hexagon') {
      return Path()
        ..moveTo(size.width * .25, 0)
        ..lineTo(size.width * .75, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(size.width * .75, size.height)
        ..lineTo(size.width * .25, size.height)
        ..lineTo(0, size.height / 2)
        ..close();
    }
    if (shape == 'rounded') {
      return Path()
        ..addRRect(RRect.fromRectAndRadius(
            Offset.zero & size, const Radius.circular(14)));
    }
    return Path()..addRect(Offset.zero & size);
  }

  @override
  bool shouldReclip(covariant _StoreLogoShapeClipper oldClipper) =>
      oldClipper.shape != shape;
}
