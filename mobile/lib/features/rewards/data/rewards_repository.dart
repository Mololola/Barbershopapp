import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/payout_request.dart';
import '../domain/reward_ledger_entry.dart';

class RewardsRepository {
  RewardsRepository(this._client);

  final SupabaseClient _client;

  // reward_ledger itself has no client-side write policy — only FastAPI
  // (bypassing RLS) ever inserts into it, see backend/app/api/rewards.py.
  // payout_requests is different: a customer can insert/read their own.

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

  Future<List<PayoutRequest>> fetchMyPayoutRequests(String profileId) async {
    final rows = await _client
        .from('payout_requests')
        .select()
        .eq('profile_id', profileId)
        .order('requested_at', ascending: false);
    return rows.map(PayoutRequest.fromRow).toList();
  }

  Future<void> requestPayout({required String profileId, required int amountCents}) async {
    await _client.from('payout_requests').insert({
      'profile_id': profileId,
      'amount_cents': amountCents,
    });
  }
}
