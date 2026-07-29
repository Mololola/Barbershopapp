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

  /// Matches the backend's 60-day clock in
  /// backend/app/jobs/expire_grace_periods.py — null once that's passed
  /// (the business would already be gone by then).
  int? get graceDaysRemaining {
    if (suspendedAt == null) return null;
    final elapsed = DateTime.now().toUtc().difference(suspendedAt!).inDays;
    final remaining = 60 - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  factory BusinessSubscription.fromRow(Map<String, dynamic> row) {
    return BusinessSubscription(
      status: SubscriptionStatusX.fromWireValue(row['status'] as String),
      grandfathered: row['grandfathered'] as bool,
      monthlyAmountCents: row['monthly_amount_cents'] as int,
      suspendedAt: row['suspended_at'] != null ? DateTime.parse(row['suspended_at'] as String) : null,
    );
  }
}
