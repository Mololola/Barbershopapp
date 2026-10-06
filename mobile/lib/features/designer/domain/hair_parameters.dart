/// Bumped when the meaning of stored values changes; designer.js converts
/// older designs on load (v2: the scalp map reaches down to the nape; v3:
/// haircut presets — older designs become the 'custom' preset; v4: a hair
/// type instead of a curl amount).
const currentDesignVersion = 4;

/// A design as `assets/haircut_designer/designer.js` describes it — the one
/// typed shape both the WebView bridge and the `haircut_designs.parameters`
/// JSONB column go through, instead of passing raw maps around.
class HairParameters {
  const HairParameters({
    this.version = currentDesignVersion,
    this.preset = 'custom',
    this.length = 8,
    this.volume = 1,
    this.hairType = '1B',
    this.colorHex = '#3b2314',
    this.partOffset = 0,
    this.fadeHeight = 0.3,
    this.fadeTo = 0,
    this.fadeShape = 'classic',
    this.zones = const {},
    this.undercut = const UndercutParameters(),
    this.faceParams = const FaceParameters(),
    this.strokes = const [],
  });

  final int version;

  /// One of [haircutPresets]' ids — the cut the design starts from.
  final String preset;

  /// The top's length in 0.5 cm units: 0 (shaved) .. 100 (50 cm). The
  /// preset sets the other regions relative to it.
  final double length;

  /// 0.2 (sparse) .. 2 (very thick).
  final double volume;

  /// One of [hairTypes]' ids, '1A' .. '4C'.
  final String hairType;

  final String colorHex;

  /// -1 (left) .. 1 (right), 0 = no part.
  final double partOffset;

  /// 0 (no fade) .. 1 (high fade). Presets fade down to skin; 'custom'
  /// (designs from before presets) tapers without reaching skin.
  final double fadeHeight;

  /// The clipper guard the fade finishes at, 0 (skin) .. 8 — a shadow fade
  /// stops at #1 or #2.
  final int fadeTo;

  /// One of [fadeShapes]' ids.
  final String fadeShape;

  /// The other zones' lengths, in the same 0.5 cm units as [length] (the
  /// top's): 'fringe', 'crown', 'sides', 'back', 'nape' (see [hairZones]).
  /// Empty until designer.js fills them in from the cut.
  final Map<String, double> zones;

  final UndercutParameters undercut;

  final FaceParameters faceParams;

  /// Freehand clipper/scissors/razor/dye strokes painted onto the scalp,
  /// applied on top of the base style above. Order matters — later strokes
  /// are rasterized over earlier ones (see designer.js's mask replay).
  final List<HairStroke> strokes;

  HairParameters copyWith({
    String? preset,
    double? length,
    double? volume,
    String? hairType,
    String? colorHex,
    double? partOffset,
    double? fadeHeight,
    int? fadeTo,
    String? fadeShape,
    Map<String, double>? zones,
    UndercutParameters? undercut,
    FaceParameters? faceParams,
    List<HairStroke>? strokes,
  }) {
    return HairParameters(
      version: version,
      preset: preset ?? this.preset,
      length: length ?? this.length,
      volume: volume ?? this.volume,
      hairType: hairType ?? this.hairType,
      colorHex: colorHex ?? this.colorHex,
      partOffset: partOffset ?? this.partOffset,
      fadeHeight: fadeHeight ?? this.fadeHeight,
      fadeTo: fadeTo ?? this.fadeTo,
      fadeShape: fadeShape ?? this.fadeShape,
      zones: zones ?? this.zones,
      undercut: undercut ?? this.undercut,
      faceParams: faceParams ?? this.faceParams,
      strokes: strokes ?? this.strokes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'preset': preset,
      'length': length,
      'volume': volume,
      'hairType': hairType,
      'colorHex': colorHex,
      'partOffset': partOffset,
      'fadeHeight': fadeHeight,
      'fadeTo': fadeTo,
      'fadeShape': fadeShape,
      // Left out until known, so designer.js derives them from the cut.
      if (zones.isNotEmpty) 'zones': zones,
      'undercut': undercut.toJson(),
      'faceParams': faceParams.toJson(),
      'strokes': strokes.map((s) => s.toJson()).toList(),
    };
  }

  factory HairParameters.fromJson(Map<String, dynamic> json) {
    return HairParameters(
      // Designs saved before versioning are v1, and before presets 'custom'.
      version: (json['version'] as num?)?.toInt() ?? 1,
      preset: json['preset'] as String? ?? 'custom',
      length: (json['length'] as num?)?.toDouble() ?? 8,
      volume: (json['volume'] as num?)?.toDouble() ?? 1,
      hairType: json['hairType'] as String? ?? hairTypeFromCurl((json['curl'] as num?)?.toDouble() ?? 0),
      colorHex: json['colorHex'] as String? ?? '#3b2314',
      partOffset: (json['partOffset'] as num?)?.toDouble() ?? 0,
      fadeHeight: (json['fadeHeight'] as num?)?.toDouble() ?? 0.3,
      fadeTo: (json['fadeTo'] as num?)?.toInt() ?? 0,
      fadeShape: json['fadeShape'] as String? ?? 'classic',
      zones: (json['zones'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? const {},
      undercut: json['undercut'] == null
          ? const UndercutParameters()
          : UndercutParameters.fromJson(json['undercut'] as Map<String, dynamic>),
      faceParams: json['faceParams'] == null
          ? const FaceParameters()
          : FaceParameters.fromJson(json['faceParams'] as Map<String, dynamic>),
      strokes: (json['strokes'] as List<dynamic>?)
              ?.map((s) => HairStroke.fromJson(s as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// A disconnected undercut: a hard line, short (a guard) below it.
class UndercutParameters {
  const UndercutParameters({this.on = false, this.height = 0.5, this.guard = 2});

  final bool on;

  /// Where the line is: 0 (low, near the ears) .. 1 (high, toward the top).
  final double height;

  /// Clipper guard below the line, 0 (skin) .. 8.
  final int guard;

  UndercutParameters copyWith({bool? on, double? height, int? guard}) =>
      UndercutParameters(on: on ?? this.on, height: height ?? this.height, guard: guard ?? this.guard);

  Map<String, dynamic> toJson() => {'on': on, 'height': height, 'guard': guard};

  factory UndercutParameters.fromJson(Map<String, dynamic> json) => UndercutParameters(
        on: json['on'] as bool? ?? false,
        height: (json['height'] as num?)?.toDouble() ?? 0.5,
        guard: (json['guard'] as num?)?.toInt() ?? 2,
      );
}

/// The zones besides the top, front to back — keys of [HairParameters.zones]
/// and groom.js ZONES.
const hairZones = [
  (id: 'fringe', label: 'Fringe'),
  (id: 'crown', label: 'Crown'),
  (id: 'sides', label: 'Sides'),
  (id: 'back', label: 'Back'),
  (id: 'nape', label: 'Nape'),
];

/// Ids match fadeReach/fadeStart in groom.js.
const fadeShapes = [
  (id: 'classic', label: 'Classic', description: 'Even all the way round'),
  (id: 'taper', label: 'Taper', description: 'Only the sideburns and neckline'),
  (id: 'drop', label: 'Drop', description: 'Curves down behind the ear'),
  (id: 'burst', label: 'Burst', description: 'A half-circle round the ear'),
];

/// Designs before v4 had one 'curl' amount, 0..1, instead of a hair type.
/// Must match hairTypeFromCurl in designer.js.
String hairTypeFromCurl(double curl) {
  if (curl < 0.15) return '1B';
  if (curl < 0.45) return '2B';
  if (curl < 0.8) return '3B';
  return '4A';
}

/// The 1A-4C hair types — ids match HAIR_TYPES in
/// `assets/haircut_designer/groom.js`, which holds what each one looks like.
const hairTypes = [
  (id: '1A', family: 'Straight', description: 'Fine, pin-straight and shiny'),
  (id: '1B', family: 'Straight', description: 'Straight with some body'),
  (id: '1C', family: 'Straight', description: 'Thick, with slight bends'),
  (id: '2A', family: 'Wavy', description: 'Loose, fine S-waves'),
  (id: '2B', family: 'Wavy', description: 'Defined S-waves'),
  (id: '2C', family: 'Wavy', description: 'Thick, voluminous waves'),
  (id: '3A', family: 'Curly', description: 'Large, loose spirals'),
  (id: '3B', family: 'Curly', description: 'Springy ringlets'),
  (id: '3C', family: 'Curly', description: 'Tight, pencil-sized corkscrews'),
  (id: '4A', family: 'Coily', description: 'Soft S-pattern coils'),
  (id: '4B', family: 'Coily', description: 'Z-pattern zig-zag coils'),
  (id: '4C', family: 'Coily', description: 'Tight, dense coils'),
];

/// Kept separate from [HairParameters] since face customization is expected
/// to grow (face shape, eye color, ...) independently of hair styling.
class FaceParameters {
  const FaceParameters({this.skinTone = '#e0ac69'});

  final String skinTone;

  FaceParameters copyWith({String? skinTone}) {
    return FaceParameters(skinTone: skinTone ?? this.skinTone);
  }

  Map<String, dynamic> toJson() => {'skinTone': skinTone};

  factory FaceParameters.fromJson(Map<String, dynamic> json) {
    return FaceParameters(skinTone: json['skinTone'] as String? ?? '#e0ac69');
  }
}

/// A single freehand tool application painted onto the scalp — the polyline
/// the finger/cursor traced, in the follicle UV space designer.js already
/// computes from (polar, azimuth). See designer.js's mask canvases for how
/// these get rasterized and sampled back out per-follicle.
class HairStroke {
  const HairStroke({
    required this.tool,
    required this.radius,
    required this.points,
    this.guard,
    this.length,
    this.colorHex,
    this.hairType,
  });

  /// 'clipper' | 'razor' | 'dye' | 'curl' | 'cut' (the scissors), or
  /// 'scissors' — a brush to a set length, from designs before the physics
  /// scissors.
  final String tool;

  /// Clipper guard, 0 (skin) .. 8 — the real guard lengths live in
  /// groom.js (CLIPPER_GUARD_LENGTHS). Only set when tool == 'clipper'.
  final int? guard;

  /// Target length in 0.5 cm units. Only set when tool == 'scissors'.
  final double? length;

  /// Only set when tool == 'dye'.
  final String? colorHex;

  /// One of [hairTypes]' ids. Only set when tool == 'curl'.
  final String? hairType;

  /// Brush radius in UV space (0..1).
  final double radius;

  /// [[u, v], ...] sampled along the drag gesture — or for 'cut',
  /// [[u, v, length], ...]: each strand the scissors cut, at its new length.
  final List<List<double>> points;

  Map<String, dynamic> toJson() {
    return {
      'tool': tool,
      if (guard != null) 'guard': guard,
      if (length != null) 'length': length,
      if (colorHex != null) 'colorHex': colorHex,
      if (hairType != null) 'hairType': hairType,
      'radius': radius,
      'points': points,
    };
  }

  factory HairStroke.fromJson(Map<String, dynamic> json) {
    return HairStroke(
      tool: json['tool'] as String,
      guard: (json['guard'] as num?)?.toInt(),
      length: (json['length'] as num?)?.toDouble(),
      colorHex: json['colorHex'] as String?,
      hairType: json['hairType'] as String?,
      radius: (json['radius'] as num?)?.toDouble() ?? 0.03,
      points: (json['points'] as List<dynamic>)
          .map((p) => (p as List<dynamic>).map((v) => (v as num).toDouble()).toList())
          .toList(),
    );
  }
}

/// The cuts a design can start from — ids match PRESETS in
/// `assets/haircut_designer/groom.js`.
const haircutPresets = [
  (id: 'buzz', label: 'Buzz Cut', group: 'Barbershop'),
  (id: 'crew', label: 'Crew Cut', group: 'Barbershop'),
  (id: 'fade', label: 'Fade', group: 'Barbershop'),
  (id: 'undercut', label: 'Undercut', group: 'Barbershop'),
  (id: 'pompadour', label: 'Pompadour', group: 'Barbershop'),
  (id: 'quiff', label: 'Quiff', group: 'Barbershop'),
  (id: 'slickBack', label: 'Slick Back', group: 'Barbershop'),
  (id: 'texturedCrop', label: 'Textured Crop', group: 'Barbershop'),
  (id: 'mullet', label: 'Mullet', group: 'Barbershop'),
  (id: 'afro', label: 'Afro', group: 'Barbershop'),
  (id: 'bald', label: 'Bald/Shaved', group: 'Barbershop'),
  (id: 'longLayers', label: 'Long Layers', group: 'Longer cuts'),
  (id: 'bob', label: 'Bob', group: 'Longer cuts'),
  (id: 'pixie', label: 'Pixie', group: 'Longer cuts'),
  (id: 'curtains', label: 'Curtains', group: 'Longer cuts'),
  (id: 'curly', label: 'Curly', group: 'Longer cuts'),
];
