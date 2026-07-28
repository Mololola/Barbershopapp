import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/reward_ledger_entry.dart';

/// Reads only — `reward_ledger` has no client-side write policy; only
/// FastAPI (bypassing RLS) ever inserts into it, see
/// backend/app/api/rewards.py.
class RewardsRepository {
  RewardsRepository(this._client);

  final SupabaseClient _client;

  Future<int> fetchBalanceCents(String customerId) async {
    final rows = await _client.from('reward_ledger').select('amount_cents').eq('customer_id', customerId);
    return rows.fold<int>(0, (sum, row) => sum + (row['amount_cents'] as int));
  }

  Future<List<RewardLedgerEntry>> fetchHistory(String customerId) async {
    final rows = await _client
        .from('reward_ledger')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
    return rows.map(RewardLedgerEntry.fromRow).toList();
  }
}
