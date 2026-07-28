/// Result of attempting to credit a review's reward — not crediting (cap
/// reached, already credited) is a normal outcome, not a failure.
class RewardCredit {
  const RewardCredit({required this.credited, required this.amountCents, this.reason});

  final bool credited;
  final int amountCents;
  final String? reason;

  factory RewardCredit.fromApiJson(Map<String, dynamic> json) {
    return RewardCredit(
      credited: json['credited'] as bool,
      amountCents: json['amount_cents'] as int,
      reason: json['reason'] as String?,
    );
  }
}
