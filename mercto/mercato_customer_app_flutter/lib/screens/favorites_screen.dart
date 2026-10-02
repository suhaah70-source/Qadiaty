import 'package:flutter/material.dart';

String _tx(BuildContext context, String ar, String en) => Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: Localizations.localeOf(context).languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(_tx(context, "المفضلة", "Favorites"))),
        body: Center(
            child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.favorite_border_rounded, size: 64),
                  SizedBox(height: 12),
                  Text(_tx(context, "لا توجد منتجات في المفضلة بعد", "No favorite products yet")),
                ]))),
      ));
}
