/// Mirrors the `DEFAULT_PARAMS` shape in
/// `assets/haircut_designer/designer.js` — this is the one typed shape both
/// the WebView JS bridge and the `haircut_designs.parameters` JSONB column
/// go through, instead of passing raw maps around.
class HairParameters {
  const HairParameters({
    this.length = 8,
    this.volume = 1,
    this.curl = 0,
    this.colorHex = '#3b2314',
    this.partOffset = 0,
    this.fadeHeight = 0.3,
    this.faceParams = const FaceParameters(),
    this.strokes = const [],
  });

  /// 0 (shaved) .. 20 (long).
  final double length;

  /// 0.2 (sparse) .. 2 (very thick).
  final double volume;

  /// 0 (straight) .. 1 (tight curl).
  final double curl;

  final String colorHex;

  /// -1 (left) .. 1 (right), 0 = no part.
  final double partOffset;

  /// 0 (no fade, even length) .. 1 (high, tight fade).
  final double fadeHeight;

  final FaceParameters faceParams;

  /// Freehand clipper/scissors/razor/dye strokes painted onto the scalp,
  /// applied on top of the base style above. Order matters — later strokes
  /// are rasterized over earlier ones (see designer.js's mask replay).
  final List<HairStroke> strokes;

  HairParameters copyWith({
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

  /// 'clipper' | 'scissors' | 'razor' | 'dye'.
  final String tool;

  /// Clipper guard size, 0 (skin) .. 8 — fixed guard→length table lives in
  /// designer.js. Only set when tool == 'clipper'.
  final int? guard;

  /// Continuous target length, 0..20. Only set when tool == 'scissors'.
  final double? length;

  /// Only set when tool == 'dye'.
  final String? colorHex;

  /// Brush radius in UV space (0..1).
  final double radius;

  /// [[u, v], ...] sampled along the drag gesture.
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
