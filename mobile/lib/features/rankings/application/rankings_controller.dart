import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_providers.dart';
import '../data/rankings_repository.dart';
import '../domain/ranking_entry.dart';
import '../domain/ranking_window.dart';

final rankingsRepositoryProvider = Provider<RankingsRepository>((ref) {
  return RankingsRepository(ref.watch(supabaseClientProvider));
});

final distinctShopsRankingProvider =
    FutureProvider.family<List<CustomerRankingEntry>, RankingWindow>((ref, window) {
  return ref.watch(rankingsRepositoryProvider).fetchDistinctShops(window);
});

final totalHaircutsRankingProvider =
    FutureProvider.family<List<CustomerRankingEntry>, RankingWindow>((ref, window) {
  return ref.watch(rankingsRepositoryProvider).fetchTotalHaircuts(window);
});

final haircutTypesRankingProvider =
    FutureProvider.family<List<HaircutTypeRankingEntry>, RankingWindow>((ref, window) {
  return ref.watch(rankingsRepositoryProvider).fetchHaircutTypes(window);
});

final referralsRankingProvider = FutureProvider<List<CustomerRankingEntry>>((ref) {
  return ref.watch(rankingsRepositoryProvider).fetchReferrals();
});
