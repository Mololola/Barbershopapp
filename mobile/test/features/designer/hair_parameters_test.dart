import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/designer/domain/hair_parameters.dart';

void main() {
  test('toJson/fromJson round-trips every field', () {
    const original = HairParameters(
      length: 14.5,
      volume: 1.75,
      curl: 0.6,
      colorHex: '#8a3324',
      partOffset: -0.5,
      fadeHeight: 0.9,
    );

    final restored = HairParameters.fromJson(original.toJson());

    expect(restored.length, original.length);
    expect(restored.volume, original.volume);
    expect(restored.curl, original.curl);
    expect(restored.colorHex, original.colorHex);
    expect(restored.partOffset, original.partOffset);
    expect(restored.fadeHeight, original.fadeHeight);
  });

  test('fromJson fills in defaults for missing fields', () {
    final restored = HairParameters.fromJson({'colorHex': '#000000'});

    expect(restored.colorHex, '#000000');
    expect(restored.length, const HairParameters().length);
    expect(restored.volume, const HairParameters().volume);
    expect(restored.curl, const HairParameters().curl);
    expect(restored.partOffset, const HairParameters().partOffset);
    expect(restored.fadeHeight, const HairParameters().fadeHeight);
  });

  test('copyWith only overrides the given fields', () {
    const original = HairParameters(length: 5, colorHex: '#000000');
    final updated = original.copyWith(length: 10);

    expect(updated.length, 10);
    expect(updated.colorHex, '#000000');
  });
}
