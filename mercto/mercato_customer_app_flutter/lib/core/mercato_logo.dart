import 'package:flutter/material.dart';

class MercatoLogoMark extends StatelessWidget {
  const MercatoLogoMark({super.key, this.size = 80});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Image.asset('assets/icon/icon.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(Icons.storefront_rounded,
                size: size * .72,
                color: Theme.of(context).colorScheme.secondary)),
      );
}
