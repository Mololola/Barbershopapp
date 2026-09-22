import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/rewards_repository.dart';
import '../domain/payout_request.dart';
import '../domain/reward_ledger_entry.dart';

final rewardsRepositoryProvider = Provider<RewardsRepository>((ref) {
  return RewardsRepository(ref.watch(supabaseClientProvider));
});

final rewardBalanceProvider = FutureProvider<int>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return 0;
  return ref.watch(rewardsRepositoryProvider).fetchBalanceCents(profile.id);
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

/// reward_ledger is append-only earnings (see its own amount_cents >= 0
/// constraint) — a request doesn't touch it, so "what can I still ask for"
/// is computed here by reading both, not by writing anywhere. Only
/// 'rejected' requests don't count against the balance — pending/approved
/// /paid all mean that money is already spoken for.
int availableBalanceCents(int ledgerBalanceCents, List<PayoutRequest> myRequests) {
  final spokenFor = myRequests
      .where((r) => r.status != PayoutRequestStatus.rejected)
      .fold<int>(0, (sum, r) => sum + r.amountCents);
  final available = ledgerBalanceCents - spokenFor;
  return available < 0 ? 0 : available;
}

final availableBalanceProvider = FutureProvider.autoDispose<int>((ref) async {
  final ledgerBalance = await ref.watch(rewardBalanceProvider.future);
  final myRequests = await ref.watch(myPayoutRequestsProvider.future);
  return availableBalanceCents(ledgerBalance, myRequests);
});

final payoutControllerProvider = AsyncNotifierProvider<PayoutController, void>(PayoutController.new);

class PayoutController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> requestPayout(int amountCents) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      final profile = await ref.read(currentProfileProvider.future);
      if (profile == null) throw StateError('No signed-in profile.');
      await ref.read(rewardsRepositoryProvider).requestPayout(profileId: profile.id, amountCents: amountCents);
      ref.invalidate(myPayoutRequestsProvider);
      ref.invalidate(availableBalanceProvider);
      success = true;
    });
    return success;
  }
}
