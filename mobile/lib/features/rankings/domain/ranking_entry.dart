/// Rankings 1, 2, 3 — customers ranked by a count.
class CustomerRankingEntry {
  const CustomerRankingEntry({
    required this.customerId,
    required this.username,
    required this.avatarUrl,
    required this.value,
  });

  final String customerId;
  final String username;
  final String? avatarUrl;
  final int value;

  factory CustomerRankingEntry.fromRow(Map<String, dynamic> row) {
    return CustomerRankingEntry(
      customerId: row['customer_id'] as String,
      username: row['username'] as String,
      avatarUrl: row['avatar_url'] as String?,
      value: row['value'] as int,
    );
  }
}

/// Ranking 4 — haircut types ranked by popularity, not customers.
class HaircutTypeRankingEntry {
  const HaircutTypeRankingEntry({required this.haircutType, required this.value});

  final String haircutType;
  final int value;

  factory HaircutTypeRankingEntry.fromRow(Map<String, dynamic> row) {
    return HaircutTypeRankingEntry(
      haircutType: row['haircut_type'] as String,
      value: row['value'] as int,
    );
  }
}
