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

  HairParameters copyWith({
    double? length,
    double? volume,
    double? curl,
    String? colorHex,
    double? partOffset,
    double? fadeHeight,
  }) {
    return HairParameters(
      length: length ?? this.length,
      volume: volume ?? this.volume,
      curl: curl ?? this.curl,
      colorHex: colorHex ?? this.colorHex,
      partOffset: partOffset ?? this.partOffset,
      fadeHeight: fadeHeight ?? this.fadeHeight,
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
    );
  }
}
