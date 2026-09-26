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
    // business_id is unique on business_subscriptions, so PostgREST embeds
    // it one-to-one: a single object, or null for a business that has never
    // gone through checkout — not a list.
    final subscription = row['business_subscriptions'] as Map<String, dynamic>?;
    return AdminBusinessSummary(
      id: row['id'] as String,
      name: row['name'] as String,
      ownerUsername: (row['owner'] as Map<String, dynamic>)['username'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      subscriptionStatus: subscription?['status'] as String?,
      subscriptionTrialEndsAt: row['subscription_trial_ends_at'] != null
          ? DateTime.parse(row['subscription_trial_ends_at'] as String)
          : null,
    );
  }
}
