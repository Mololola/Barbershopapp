import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/business/domain/brand.dart';

double _luminance(Color c) {
  double channel(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

void main() {
  test('every palette colour carries white text at WCAG AA (4.5:1)', () {
    for (final entry in brandPalette.entries) {
      final contrast = (1.0 + 0.05) / (_luminance(entry.value) + 0.05);
      expect(contrast, greaterThanOrEqualTo(4.5), reason: '${entry.key} is only ${contrast.toStringAsFixed(2)}:1');
    }
  });

  test('a stored colour wins; without one a shop always gets the same palette colour', () {
    expect(brandColorOf(businessId: 'abc', storedHex: '#1F3A5F'), const Color(0xFF1F3A5F));
    final assigned = brandColorOf(businessId: 'd5f8bde3-95e8-402e-930b-17de7b3596b2');
    expect(brandPalette.values, contains(assigned));
    expect(brandColorOf(businessId: 'd5f8bde3-95e8-402e-930b-17de7b3596b2'), assigned);
  });

  test('hex round-trips in the form the database accepts', () {
    for (final colour in brandPalette.values) {
      final hex = brandColorToHex(colour);
      expect(hex, matches(RegExp(r'^#[0-9A-F]{6}$')));
      expect(brandColorOf(businessId: 'x', storedHex: hex), colour);
    }
  });

  test('initials: first letters of the first two words', () {
    expect(initialsOf('Molola Enterprises'), 'ME');
    expect(initialsOf('fades'), 'F');
    expect(initialsOf('  The Cut  Club '), 'TC');
    expect(initialsOf(''), '?');
  });
}
