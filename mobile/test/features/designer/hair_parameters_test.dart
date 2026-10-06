import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/designer/domain/hair_parameters.dart';

void main() {
  test('toJson/fromJson round-trips every field', () {
    const original = HairParameters(
      length: 14.5,
      volume: 1.75,
      hairType: '3C',
      colorHex: '#8a3324',
      partOffset: -0.5,
      fadeHeight: 0.9,
      faceParams: FaceParameters(skinTone: '#c68642'),
      strokes: [
        HairStroke(tool: 'clipper', guard: 3, radius: 0.05, points: [
          [0.2, 0.3],
          [0.25, 0.35],
        ]),
        HairStroke(tool: 'dye', colorHex: '#ff00ff', radius: 0.02, points: [
          [0.6, 0.1],
        ]),
        HairStroke(tool: 'curl', hairType: '4A', radius: 0.03, points: [
          [0.4, 0.2],
        ]),
      ],
    );

    final restored = HairParameters.fromJson(original.toJson());

    expect(restored.length, original.length);
    expect(restored.volume, original.volume);
    expect(restored.hairType, '3C');
    expect(restored.colorHex, original.colorHex);
    expect(restored.partOffset, original.partOffset);
    expect(restored.fadeHeight, original.fadeHeight);
    expect(restored.faceParams.skinTone, '#c68642');
    expect(restored.strokes, hasLength(3));
    expect(restored.strokes[0].tool, 'clipper');
    expect(restored.strokes[0].guard, 3);
    expect(restored.strokes[0].points, [
      [0.2, 0.3],
      [0.25, 0.35],
    ]);
    expect(restored.strokes[1].tool, 'dye');
    expect(restored.strokes[1].colorHex, '#ff00ff');
    expect(restored.strokes[2].hairType, '4A');
  });

  test('fromJson fills in defaults for missing fields', () {
    final restored = HairParameters.fromJson({'colorHex': '#000000'});

    expect(restored.colorHex, '#000000');
    expect(restored.length, const HairParameters().length);
    expect(restored.volume, const HairParameters().volume);
    expect(restored.hairType, const HairParameters().hairType);
    expect(restored.partOffset, const HairParameters().partOffset);
    expect(restored.fadeHeight, const HairParameters().fadeHeight);
    expect(restored.faceParams.skinTone, const FaceParameters().skinTone);
    expect(restored.strokes, isEmpty);
  });

  test('fromJson on a pre-existing saved design (no faceParams/strokes keys) still loads', () {
    final legacyJson = {
      'length': 10.0,
      'volume': 1.2,
      'curl': 0.3,
      'colorHex': '#3b2314',
      'partOffset': 0.0,
      'fadeHeight': 0.5,
    };

    final restored = HairParameters.fromJson(legacyJson);

    expect(restored.length, 10.0);
    // curl 0.3 was "wavy".
    expect(restored.hairType, '2B');
    expect(restored.faceParams.skinTone, const FaceParameters().skinTone);
    expect(restored.strokes, isEmpty);
    // Unversioned means v1, so designer.js converts its strokes to the v2 scalp map.
    expect(restored.version, 1);
  });

  test('new designs are the current version, and the version round-trips', () {
    expect(const HairParameters().version, currentDesignVersion);
    expect(HairParameters.fromJson(const HairParameters().toJson()).version, currentDesignVersion);
  });

  test('the preset round-trips, and designs from before presets are custom', () {
    expect(HairParameters.fromJson(const HairParameters(preset: 'pompadour').toJson()).preset, 'pompadour');
    expect(HairParameters.fromJson({'length': 10.0, 'version': 2}).preset, 'custom');
  });

  test('scissors cuts keep each strand\'s new length as a third coordinate', () {
    const original = HairParameters(strokes: [
      HairStroke(tool: 'cut', radius: 0.004, points: [
        [0.25, 0.4, 12.5],
      ]),
    ]);
    expect(HairParameters.fromJson(original.toJson()).strokes.single.points.single, [0.25, 0.4, 12.5]);
  });

  test('hair type ids are unique and run 1A to 4C', () {
    final ids = hairTypes.map((t) => t.id).toList();
    expect(ids.toSet(), hasLength(12));
    expect(ids.first, '1A');
    expect(ids.last, '4C');
  });

  test('preset ids are unique', () {
    final ids = haircutPresets.map((p) => p.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('copyWith only overrides the given fields', () {
    const original = HairParameters(length: 5, colorHex: '#000000');
    final updated = original.copyWith(length: 10);

    expect(updated.length, 10);
    expect(updated.colorHex, '#000000');
  });
}
