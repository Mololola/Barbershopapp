class RewardLedgerEntry {
  const RewardLedgerEntry({
    required this.id,
    required this.amountCents,
    required this.currency,
    required this.createdAt,
    this.isReferral = false,
  });

  final String id;
  final int amountCents;
  final String currency;
  final DateTime createdAt;
  final bool isReferral;

  factory RewardLedgerEntry.fromRow(Map<String, dynamic> row) {
    return RewardLedgerEntry(
      id: row['id'] as String,
      amountCents: row['amount_cents'] as int,
      currency: row['currency'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      isReferral: row['source'] == 'referral',
    );
  }
}
