class RewardLedgerEntry {
  const RewardLedgerEntry({required this.id, required this.amountCents, required this.createdAt});

  final String id;
  final int amountCents;
  final DateTime createdAt;

  factory RewardLedgerEntry.fromRow(Map<String, dynamic> row) {
    return RewardLedgerEntry(
      id: row['id'] as String,
      amountCents: row['amount_cents'] as int,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
