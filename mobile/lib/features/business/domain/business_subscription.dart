enum SubscriptionStatus { incomplete, active, pastDue, suspended, canceled }

extension SubscriptionStatusX on SubscriptionStatus {
  static SubscriptionStatus fromWireValue(String value) {
    switch (value) {
      case 'incomplete':
        return SubscriptionStatus.incomplete;
      case 'active':
        return SubscriptionStatus.active;
      case 'past_due':
        return SubscriptionStatus.pastDue;
      case 'suspended':
        return SubscriptionStatus.suspended;
      case 'canceled':
        return SubscriptionStatus.canceled;
      default:
        throw ArgumentError('Unknown subscription status: $value');
    }
  }
}

class BusinessSubscription {
  const BusinessSubscription({
    required this.status,
    required this.grandfathered,
    required this.monthlyAmountCents,
    this.suspendedAt,
  });

  final SubscriptionStatus status;
  final bool grandfathered;
  final int monthlyAmountCents;
  final DateTime? suspendedAt;

  /// How long an unpaid shop's data is kept after it's hidden — mirrors
  /// GRACE_PERIOD_DAYS in backend/app/jobs/expire_grace_periods.py.
  static const dataRetention = Duration(days: 60);

  /// When a lapsed shop stops being shown to customers — mirrors the
  /// backend's business_hidden_since (migration f1c9a7d3e5b2).
  DateTime? get hiddenAt => suspendedAt?.add(const Duration(days: 3));

  factory BusinessSubscription.fromRow(Map<String, dynamic> row) {
    return BusinessSubscription(
      status: SubscriptionStatusX.fromWireValue(row['status'] as String),
      grandfathered: row['grandfathered'] as bool,
      monthlyAmountCents: row['monthly_amount_cents'] as int,
      suspendedAt: row['suspended_at'] != null ? DateTime.parse(row['suspended_at'] as String) : null,
    );
  }
}
