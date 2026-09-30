/// A business as seen by customers browsing to book — deliberately excludes
/// `phone` (the spec: internal records only, never public). Backed by the
/// `businesses_public` view, not the `businesses` table.
class PublicBusiness {
  const PublicBusiness({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.currency,
    this.logoUrl,
    this.coverUrl,
    this.brandColor,
    this.averageRating,
    this.reviewCount = 0,
  });

  final String id;

  /// The owner's profile — whose posts appear on the shop page and who a
  /// customer's message goes to.
  final String ownerId;
  final String name;
  final String currency;
  final String? logoUrl;
  final String? coverUrl;

  /// "#RRGGBB", or null until the owner picks one (see brandColorOf).
  final String? brandColor;
  final double? averageRating;
  final int reviewCount;

  factory PublicBusiness.fromRow(Map<String, dynamic> row) {
    return PublicBusiness(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      name: row['name'] as String,
      currency: row['currency'] as String,
      logoUrl: row['logo_url'] as String?,
      coverUrl: row['cover_url'] as String?,
      brandColor: row['brand_color'] as String?,
      averageRating: (row['average_rating'] as num?)?.toDouble(),
      reviewCount: row['review_count'] as int? ?? 0,
    );
  }
}
