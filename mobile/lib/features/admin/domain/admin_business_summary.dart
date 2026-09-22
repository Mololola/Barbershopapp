/// Admin-only view of a business — deliberately separate from the
/// customer-facing `Business`/`PublicBusiness` models rather than
/// overloading them with fields no customer screen needs.
class AdminBusinessSummary {
  const AdminBusinessSummary({
    required this.id,
    required this.name,
    required this.ownerUsername,
    required this.createdAt,
    this.subscriptionStatus,
    this.subscriptionTrialEndsAt,
  });

  final String id;
  final String name;
  final String ownerUsername;
  final DateTime createdAt;

  /// Null means no `business_subscriptions` row exists yet — a brand-new
  /// business that hasn't gone through checkout at all.
  final String? subscriptionStatus;

  final DateTime? subscriptionTrialEndsAt;

  bool get hasActiveTrial => subscriptionTrialEndsAt != null && subscriptionTrialEndsAt!.isAfter(DateTime.now());

  factory AdminBusinessSummary.fromRow(Map<String, dynamic> row) {
    // business_subscriptions is embedded as a list (same convention as
    // post.dart's post_media/likes/comments) even though business_id is
    // unique on that table — a brand-new business just has an empty list,
    // never having gone through checkout at all.
    final subscriptions = row['business_subscriptions'] as List;
    final subscription = subscriptions.isEmpty ? null : subscriptions.first as Map<String, dynamic>;
    return AdminBusinessSummary(
      id: row['id'] as String,
      name: row['name'] as String,
      ownerUsername: (row['profiles'] as Map<String, dynamic>)['username'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      subscriptionStatus: subscription?['status'] as String?,
      subscriptionTrialEndsAt: row['subscription_trial_ends_at'] != null
          ? DateTime.parse(row['subscription_trial_ends_at'] as String)
          : null,
    );
  }
}
