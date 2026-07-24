/// A business as seen by customers browsing to book — deliberately excludes
/// `phone` (the spec: internal records only, never public). Backed by the
/// `businesses_public` view, not the `businesses` table.
class PublicBusiness {
  const PublicBusiness({required this.id, required this.name, required this.currency});

  final String id;
  final String name;
  final String currency;

  factory PublicBusiness.fromRow(Map<String, dynamic> row) {
    return PublicBusiness(
      id: row['id'] as String,
      name: row['name'] as String,
      currency: row['currency'] as String,
    );
  }
}
