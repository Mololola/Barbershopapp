import 'package:flutter/material.dart';

/// The colours a shop can brand its page with. Every one carries white text
/// at WCAG AA contrast (see brand_test.dart), so a shop can't pick one that
/// makes its own name unreadable.
const brandPalette = <String, Color>{
  'Charcoal': Color(0xFF2B2622),
  'Oxblood': Color(0xFF7A2E2E),
  'Rust': Color(0xFF8C4A32),
  'Bronze': Color(0xFF6E5220),
  'Forest': Color(0xFF2F5D46),
  'Teal': Color(0xFF1F5E63),
  'Navy': Color(0xFF1F3A5F),
  'Plum': Color(0xFF5B3A63),
};

/// "#1F3A5F" — the form stored in businesses.brand_color.
String brandColorToHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// The shop's chosen colour, or — until it picks one — a palette colour
/// derived from its id, so shops without branding still look distinct from
/// each other and keep the same colour every time.
Color brandColorOf({required String businessId, String? storedHex}) {
  if (storedHex != null) return Color(int.parse(storedHex.substring(1), radix: 16) | 0xFF000000);
  final colours = brandPalette.values.toList();
  // Summed code units rather than String.hashCode, which isn't guaranteed
  // stable across app versions or platforms.
  final seed = businessId.codeUnits.fold(0, (sum, unit) => sum + unit);
  return colours[seed % colours.length];
}

/// "Molola Enterprises" -> "ME"; "Fades" -> "F".
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  return words.take(2).map((w) => w[0].toUpperCase()).join();
}
