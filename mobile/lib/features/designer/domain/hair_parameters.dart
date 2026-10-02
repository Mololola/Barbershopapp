/// Bumped when the meaning of stored values changes; designer.js converts
/// older designs on load (v2: the scalp map reaches down to the nape; v3:
/// haircut presets — older designs become the 'custom' preset).
const currentDesignVersion = 3;

/// A design as `assets/haircut_designer/designer.js` describes it — the one
/// typed shape both the WebView bridge and the `haircut_designs.parameters`
/// JSONB column go through, instead of passing raw maps around.
class HairParameters {
  const HairParameters({
    this.version = currentDesignVersion,
    this.preset = 'custom',
    this.length = 8,
    this.volume = 1,
    this.curl = 0,
    this.colorHex = '#3b2314',
    this.partOffset = 0,
    this.fadeHeight = 0.3,
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

  /// 0 (straight) .. 1 (tight curl).
  final double curl;

  final String colorHex;

  /// -1 (left) .. 1 (right), 0 = no part.
  final double partOffset;

  /// 0 (no fade) .. 1 (high fade). Presets fade down to skin; 'custom'
  /// (designs from before presets) tapers without reaching skin.
  final double fadeHeight;

  final FaceParameters faceParams;

  /// Freehand clipper/scissors/razor/dye strokes painted onto the scalp,
  /// applied on top of the base style above. Order matters — later strokes
  /// are rasterized over earlier ones (see designer.js's mask replay).
  final List<HairStroke> strokes;

  HairParameters copyWith({
    String? preset,
    double? length,
    double? volume,
    double? curl,
    String? colorHex,
    double? partOffset,
    double? fadeHeight,
    FaceParameters? faceParams,
    List<HairStroke>? strokes,
  }) {
    return HairParameters(
      version: version,
      preset: preset ?? this.preset,
      length: length ?? this.length,
      volume: volume ?? this.volume,
      curl: curl ?? this.curl,
      colorHex: colorHex ?? this.colorHex,
      partOffset: partOffset ?? this.partOffset,
      fadeHeight: fadeHeight ?? this.fadeHeight,
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
      'curl': curl,
      'colorHex': colorHex,
      'partOffset': partOffset,
      'fadeHeight': fadeHeight,
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
      curl: (json['curl'] as num?)?.toDouble() ?? 0,
      colorHex: json['colorHex'] as String? ?? '#3b2314',
      partOffset: (json['partOffset'] as num?)?.toDouble() ?? 0,
      fadeHeight: (json['fadeHeight'] as num?)?.toDouble() ?? 0.3,
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
  });

  /// 'clipper' | 'razor' | 'dye' | 'cut' (the scissors), or 'scissors' — a
  /// brush to a set length, from designs before the physics scissors.
  final String tool;

  /// Clipper guard, 0 (skin) .. 8 — the real guard lengths live in
  /// groom.js (CLIPPER_GUARD_LENGTHS). Only set when tool == 'clipper'.
  final int? guard;

  /// Target length in 0.5 cm units. Only set when tool == 'scissors'.
  final double? length;

  /// Only set when tool == 'dye'.
  final String? colorHex;

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
