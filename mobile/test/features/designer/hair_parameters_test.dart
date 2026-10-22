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
        HairStroke(tool: 'volume', amount: 1, mirrored: true, radius: 0.04, points: [
          [0.6, 0.2],
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
    expect(restored.strokes, hasLength(4));
    expect(restored.strokes[0].tool, 'clipper');
    expect(restored.strokes[0].guard, 3);
    expect(restored.strokes[0].points, [
      [0.2, 0.3],
      [0.25, 0.35],
    ]);
    expect(restored.strokes[1].tool, 'dye');
    expect(restored.strokes[1].colorHex, '#ff00ff');
    expect(restored.strokes[2].hairType, '4A');
    expect(restored.strokes[3].amount, 1);
    expect(restored.strokes[3].mirrored, isTrue);
    expect(restored.strokes[0].mirrored, isFalse);
  });

  test('colour round-trips, and designs saved before it have no ombré or highlights', () {
    const original = HairParameters(
      colour: ColourParameters(
        ombre: true,
        ombreHex: '#d9b380',
        ombreStart: 12.5,
        highlights: 0.3,
        highlightHexes: ['#f0d8a8', '#a0522d'],
        balayage: true,
      ),
    );

    final restored = HairParameters.fromJson(original.toJson());

    expect(restored.colour.ombre, isTrue);
    expect(restored.colour.ombreHex, '#d9b380');
    expect(restored.colour.ombreStart, 12.5);
    expect(restored.colour.highlights, 0.3);
    expect(restored.colour.highlightHexes, ['#f0d8a8', '#a0522d']);
    expect(restored.colour.balayage, isTrue);
    final old = HairParameters.fromJson({'colorHex': '#000000'}).colour;
    expect(old.ombre, isFalse);
    expect(old.highlights, 0);
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

  test('barber details round-trip', () {
    const original = HairParameters(
      fadeTo: 1,
      fadeShape: 'drop',
      zones: {'fringe': 10, 'sides': 1.2},
      undercut: UndercutParameters(on: true, height: 0.8, guard: 0),
      hairline: HairlineParameters(shape: 'widowsPeak', height: 0.7, lineUp: true, sideburns: 'long', neckline: 'v', neckHeight: 0.8),
    );
    final restored = HairParameters.fromJson(original.toJson());
    expect(restored.fadeTo, 1);
    expect(restored.fadeShape, 'drop');
    expect(restored.zones, {'fringe': 10.0, 'sides': 1.2});
    expect(restored.undercut.on, isTrue);
    expect(restored.undercut.height, 0.8);
    expect(restored.undercut.guard, 0);
    expect(restored.hairline.shape, 'widowsPeak');
    expect(restored.hairline.height, 0.7);
    expect(restored.hairline.lineUp, isTrue);
    expect(restored.hairline.sideburns, 'long');
    expect(restored.hairline.neckline, 'v');
    expect(restored.hairline.neckHeight, 0.8);
  });

  test('designs without zones leave them out, so designer.js derives them from the cut', () {
    expect(const HairParameters().toJson().containsKey('zones'), isFalse);
    expect(HairParameters.fromJson(const {}).zones, isEmpty);
    expect(HairParameters.fromJson(const {}).undercut.on, isFalse);
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
