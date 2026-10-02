import 'package:flutter/material.dart';

Color hexToColor(String hex, {Color fallback = Colors.grey}) {
  try {
    var cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) cleaned = 'FF$cleaned';
    return Color(int.parse(cleaned, radix: 16));
  } catch (_) {
    return fallback;
  }
}
