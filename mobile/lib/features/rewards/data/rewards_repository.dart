import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api_client.dart';
import '../domain/payout_details.dart';
import '../domain/payout_request.dart';
import '../domain/reward_ledger_entry.dart';

class RewardsRepository {
  RewardsRepository(this._client, this._api);

  final SupabaseClient _client;
  final ApiClient _api;

  // reward_ledger, payout_details and payout_requests are read here
  // directly but only ever written by FastAPI (bypassing RLS): it credits
  // rewards (backend/app/api/rewards.py, billing.py), validates IBANs, and
  // checks the balance before queuing a payout (backend/app/api/payouts.py).

  /// Earned per currency, e.g. {'GBP': 400, 'EUR': 1000} — never converted.
  Future<Map<String, int>> fetchBalances(String customerId) async {
    final rows = await _client.from('reward_ledger').select('amount_cents, currency').eq('customer_id', customerId);
    final balances = <String, int>{};
    for (final row in rows) {
      final currency = row['currency'] as String;
      balances[currency] = (balances[currency] ?? 0) + (row['amount_cents'] as int);
    }
    return balances;
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

  Future<PayoutDetails?> fetchPayoutDetails(String profileId) async {
    final row = await _client.from('payout_details').select().eq('profile_id', profileId).maybeSingle();
    return row == null ? null : PayoutDetails.fromRow(row);
  }

  Future<void> savePayoutDetails({required String accountHolder, required String iban}) async {
    await _api.post('/me/payout-details', body: {'account_holder': accountHolder, 'iban': iban});
  }

  Future<void> requestPayout({required int amountCents, required String currency}) async {
    await _api.post('/me/payout-requests', body: {'amount_cents': amountCents, 'currency': currency});
  }
}
