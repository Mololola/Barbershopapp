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
    this.trialEndsAt,
    this.cancelAt,
  });

  final SubscriptionStatus status;
  final bool grandfathered;
  final int monthlyAmountCents;
  final DateTime? suspendedAt;

  /// Stripe's trial end — no charge before it.
  final DateTime? trialEndsAt;

  /// Set once the owner cancels: the subscription keeps running until this
  /// moment (the end of the trial or of the paid month), then ends with no
  /// further charge.
  final DateTime? cancelAt;

  bool get isInTrial => trialEndsAt != null && trialEndsAt!.isAfter(DateTime.now());

  /// How long an unpaid shop's data is kept, counted from [suspendedAt]
  /// (the first failed payment or the end of the subscription) — mirrors
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
      trialEndsAt: row['trial_ends_at'] != null ? DateTime.parse(row['trial_ends_at'] as String) : null,
      cancelAt: row['cancel_at'] != null ? DateTime.parse(row['cancel_at'] as String) : null,
    );
  }
}

/// A running Finance Premium subscription paid through Stripe (not a free
/// trial or a grandfathered unlock — those have nothing to cancel).
class FinancePremiumSubscription {
  const FinancePremiumSubscription({this.cancelAt});

  /// Mirrors the backend's _FINANCE_PREMIUM_MONTHLY_CENTS.
  static const monthlyAmountCents = 999;

  /// Set once the owner cancels: Premium stays on until this moment.
  final DateTime? cancelAt;

  factory FinancePremiumSubscription.fromRow(Map<String, dynamic> row) => FinancePremiumSubscription(
        cancelAt: row['cancel_at'] != null ? DateTime.parse(row['cancel_at'] as String) : null,
      );
}
