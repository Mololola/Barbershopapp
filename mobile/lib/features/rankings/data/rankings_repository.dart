import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ranking_entry.dart';
import '../domain/ranking_window.dart';

/// Each ranking is computed server-side by a SECURITY DEFINER Postgres
/// function (see the migration) — aggregating across every customer's
/// bookings/reviews needs to read past each customer's own-rows-only RLS,
/// which a plain client-side query under RLS can't do.
class RankingsRepository {
  RankingsRepository(this._client);

  final SupabaseClient _client;

  String? _windowParam(RankingWindow window) => window.startDate?.toUtc().toIso8601String();

  Future<List<CustomerRankingEntry>> fetchDistinctShops(RankingWindow window) async {
    final rows = await _client.rpc('ranking_distinct_shops', params: {'window_start': _windowParam(window)});
    return (rows as List).map((row) => CustomerRankingEntry.fromRow(row as Map<String, dynamic>)).toList();
  }

  Future<List<CustomerRankingEntry>> fetchTotalHaircuts(RankingWindow window) async {
    final rows = await _client.rpc('ranking_total_haircuts', params: {'window_start': _windowParam(window)});
    return (rows as List).map((row) => CustomerRankingEntry.fromRow(row as Map<String, dynamic>)).toList();
  }

  Future<List<HaircutTypeRankingEntry>> fetchHaircutTypes(RankingWindow window) async {
    final rows = await _client.rpc('ranking_haircut_types', params: {'window_start': _windowParam(window)});
    return (rows as List).map((row) => HaircutTypeRankingEntry.fromRow(row as Map<String, dynamic>)).toList();
  }

  /// All-time only, per spec — no window param.
  Future<List<CustomerRankingEntry>> fetchReferrals() async {
    final rows = await _client.rpc('ranking_referrals');
    return (rows as List).map((row) => CustomerRankingEntry.fromRow(row as Map<String, dynamic>)).toList();
  }

  /// Career-wide, not scoped to a window or a single business — see
  /// ranking_top_barbers.
  Future<List<BarberRankingEntry>> fetchTopBarbers() async {
    final rows = await _client.rpc('ranking_top_barbers');
    return (rows as List).map((row) => BarberRankingEntry.fromRow(row as Map<String, dynamic>)).toList();
  }
}
