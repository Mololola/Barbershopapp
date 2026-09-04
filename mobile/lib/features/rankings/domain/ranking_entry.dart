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

/// Ranking 5 — barbers ranked by average review rating, career-wide (not
/// scoped to one business — see ranking_top_barbers).
class BarberRankingEntry {
  const BarberRankingEntry({
    required this.workerProfileId,
    required this.username,
    required this.avatarUrl,
    required this.value,
  });

  final String workerProfileId;
  final String username;
  final String? avatarUrl;
  final double value;

  factory BarberRankingEntry.fromRow(Map<String, dynamic> row) {
    return BarberRankingEntry(
      workerProfileId: row['worker_profile_id'] as String,
      username: row['username'] as String,
      avatarUrl: row['avatar_url'] as String?,
      value: (row['value'] as num).toDouble(),
    );
  }
}
