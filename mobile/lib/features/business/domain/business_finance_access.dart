class BusinessFinanceAccess {
  const BusinessFinanceAccess({
    required this.grandfathered,
    required this.amountCents,
    this.trialStartedAt,
    this.trialEndsAt,
    this.paidAt,
  });

  final bool grandfathered;
  final int amountCents;
  final DateTime? trialStartedAt;
  final DateTime? trialEndsAt;
  final DateTime? paidAt;

  bool get isTrialActive =>
      !grandfathered && paidAt == null && trialEndsAt != null && DateTime.now().toUtc().isBefore(trialEndsAt!);

  bool get isUnlocked => grandfathered || paidAt != null || isTrialActive;

  /// Trial started but its window has passed with no payment — the "locked,
  /// waiting on a decision" state the user described.
  bool get trialHasExpired =>
      !grandfathered && paidAt == null && trialEndsAt != null && !DateTime.now().toUtc().isBefore(trialEndsAt!);

  int? get trialDaysRemaining {
    if (trialEndsAt == null) return null;
    final remaining = trialEndsAt!.difference(DateTime.now().toUtc()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  factory BusinessFinanceAccess.fromRow(Map<String, dynamic> row) {
    return BusinessFinanceAccess(
      grandfathered: row['grandfathered'] as bool,
      amountCents: row['amount_cents'] as int,
      trialStartedAt: row['trial_started_at'] != null ? DateTime.parse(row['trial_started_at'] as String) : null,
      trialEndsAt: row['trial_ends_at'] != null ? DateTime.parse(row['trial_ends_at'] as String) : null,
      paidAt: row['paid_at'] != null ? DateTime.parse(row['paid_at'] as String) : null,
    );
  }
}
