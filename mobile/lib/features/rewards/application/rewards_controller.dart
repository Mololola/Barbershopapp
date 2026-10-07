import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../business/domain/finance_overview.dart';
import '../data/rewards_repository.dart';
import '../domain/payout_details.dart';
import '../domain/payout_request.dart';
import '../domain/reward_ledger_entry.dart';

final rewardsRepositoryProvider = Provider<RewardsRepository>((ref) {
  return RewardsRepository(ref.watch(supabaseClientProvider), ref.watch(apiClientProvider));
});

final rewardBalanceProvider = FutureProvider<Map<String, int>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return {};
  return ref.watch(rewardsRepositoryProvider).fetchBalances(profile.id);
});

final rewardHistoryProvider = FutureProvider<List<RewardLedgerEntry>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.watch(rewardsRepositoryProvider).fetchHistory(profile.id);
});

final myPayoutRequestsProvider = FutureProvider.autoDispose<List<PayoutRequest>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.watch(rewardsRepositoryProvider).fetchMyPayoutRequests(profile.id);
});

final payoutDetailsProvider = FutureProvider.autoDispose<PayoutDetails?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return null;
  return ref.watch(rewardsRepositoryProvider).fetchPayoutDetails(profile.id);
});

/// "£4 · €10" — currencies at zero are left out, and "0" when nothing is
/// left at all (no currency to show).
String formatBalances(Map<String, int> balances) {
  final nonZero = balances.entries.where((e) => e.value > 0);
  if (nonZero.isEmpty) return '0';
  return nonZero.map((e) => formatMoney(e.value, e.key)).join(' · ');
}

/// reward_ledger is append-only earnings (see its own amount_cents >= 0
/// constraint) — a request doesn't touch it, so "what can I still ask for"
/// is computed per currency by reading both, not by writing anywhere. Only
/// 'rejected' requests don't count against the balance — pending/approved
/// /paid all mean that money is already spoken for. The backend repeats
/// this check before accepting a request; this one only drives the UI.
Map<String, int> availableBalances(Map<String, int> ledgerBalances, List<PayoutRequest> myRequests) {
  final available = {...ledgerBalances};
  for (final request in myRequests.where((r) => r.status != PayoutRequestStatus.rejected)) {
    available[request.currency] = (available[request.currency] ?? 0) - request.amountCents;
  }
  return available.map((currency, cents) => MapEntry(currency, cents < 0 ? 0 : cents));
}

final availableBalanceProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final ledgerBalances = await ref.watch(rewardBalanceProvider.future);
  final myRequests = await ref.watch(myPayoutRequestsProvider.future);
  return availableBalances(ledgerBalances, myRequests);
});

final payoutControllerProvider = AsyncNotifierProvider<PayoutController, void>(PayoutController.new);

class PayoutController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns null on success, otherwise the message to show (the backend's
  /// own wording for a bad IBAN or an over-balance request).
  Future<String?> savePayoutDetails({required String accountHolder, required String iban}) {
    return _run(() async {
      await ref.read(rewardsRepositoryProvider).savePayoutDetails(accountHolder: accountHolder, iban: iban);
      ref.invalidate(payoutDetailsProvider);
    });
  }

  Future<String?> requestPayout({required int amountCents, required String currency}) {
    return _run(() async {
      await ref.read(rewardsRepositoryProvider).requestPayout(amountCents: amountCents, currency: currency);
      ref.invalidate(myPayoutRequestsProvider);
      ref.invalidate(availableBalanceProvider);
    });
  }

  Future<String?> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    final error = state.error;
    if (error == null) return null;
    return error is ApiException && error.statusCode == 400 ? error.message : 'Something went wrong — try again.';
  }
}
