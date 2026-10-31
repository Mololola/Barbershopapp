import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline_cache.dart';
import '../domain/review.dart';

/// Reviews are simple CRUD with no money/concurrency invariant, so — unlike
/// bookings — this writes directly to Supabase under RLS rather than
/// through FastAPI (see docs/architecture.md's client/backend split).
class ReviewRepository {
  ReviewRepository(this._client, this._cache);

  final SupabaseClient _client;
  final OfflineCache _cache;

  /// Every review this customer has written, by booking id — what My
  /// bookings needs for all its rows in one query.
  Future<Map<String, Review>> fetchReviewsByCustomer(String customerId) async {
    final rows = await _cache.rows('my-reviews:$customerId', () => _client.from('reviews').select().eq('customer_id', customerId));
    return {for (final row in rows) row['booking_id'] as String: Review.fromRow(row)};
  }

  Future<void> submitReview(Review review) async {
    try {
      await _client.from('reviews').insert(review.toRow());
    } on PostgrestException catch (e) {
      // 23505 on booking_id means this booking was already reviewed — the
      // end state the caller wants (a review row exists) already holds, so
      // treat it as a no-op rather than surfacing an error (e.g. a retry
      // after a review that did reach the server).
      if (e.code != '23505') rethrow;
    }
  }
}
