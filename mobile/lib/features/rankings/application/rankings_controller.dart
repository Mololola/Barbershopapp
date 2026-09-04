import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_providers.dart';
import '../data/rankings_repository.dart';
import '../domain/ranking_entry.dart';
import '../domain/ranking_window.dart';

final rankingsRepositoryProvider = Provider<RankingsRepository>((ref) {
  return RankingsRepository(ref.watch(supabaseClientProvider));
});

// autoDispose — a leaderboard is stale the moment anyone else completes a
// booking or review, which nothing here can know to invalidate directly.
// Dropping the cache when the screen isn't watching it means re-opening
// Rankings always re-fetches instead of showing however-old data.
final distinctShopsRankingProvider =
    FutureProvider.autoDispose.family<List<CustomerRankingEntry>, RankingWindow>((ref, window) {
  return ref.watch(rankingsRepositoryProvider).fetchDistinctShops(window);
});

final totalHaircutsRankingProvider =
    FutureProvider.autoDispose.family<List<CustomerRankingEntry>, RankingWindow>((ref, window) {
  return ref.watch(rankingsRepositoryProvider).fetchTotalHaircuts(window);
});

final haircutTypesRankingProvider =
    FutureProvider.autoDispose.family<List<HaircutTypeRankingEntry>, RankingWindow>((ref, window) {
  return ref.watch(rankingsRepositoryProvider).fetchHaircutTypes(window);
});

final referralsRankingProvider = FutureProvider.autoDispose<List<CustomerRankingEntry>>((ref) {
  return ref.watch(rankingsRepositoryProvider).fetchReferrals();
});

final topBarbersRankingProvider = FutureProvider.autoDispose<List<BarberRankingEntry>>((ref) {
  return ref.watch(rankingsRepositoryProvider).fetchTopBarbers();
});
