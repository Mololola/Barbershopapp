import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/rewards_repository.dart';
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
