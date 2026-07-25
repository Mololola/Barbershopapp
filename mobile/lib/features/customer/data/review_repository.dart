import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/review.dart';

/// Reviews are simple CRUD with no money/concurrency invariant, so — unlike
/// bookings — this writes directly to Supabase under RLS rather than
/// through FastAPI (see docs/architecture.md's client/backend split).
class ReviewRepository {
  ReviewRepository(this._client);

  final SupabaseClient _client;

  Future<Review?> fetchReviewForBooking(String bookingId) async {
    final row = await _client.from('reviews').select().eq('booking_id', bookingId).maybeSingle();
    if (row == null) return null;
    return Review.fromRow(row);
  }

  Future<void> submitReview(Review review) async {
    try {
      await _client.from('reviews').insert({
        'booking_id': review.bookingId,
        'business_id': review.businessId,
        'worker_id': review.workerId,
        'customer_id': review.customerId,
        'shop_rating': review.shopRating,
        'shop_comment': review.shopComment,
        'worker_rating': review.workerRating,
        'worker_comment': review.workerComment,
        'haircut_rating': review.haircutRating,
        'haircut_comment': review.haircutComment,
        'haircut_type': review.haircutType,
      });
    } on PostgrestException catch (e) {
      // 23505 on booking_id means this booking was already reviewed — the
      // end state the caller wants (a review row exists) already holds, so
      // treat it as a no-op rather than surfacing an error. Guards against
      // the redirect gate re-entering this screen for a booking it already
      // submitted for (see pendingReviewProvider's post-submit refresh).
      if (e.code != '23505') rethrow;
    }
  }
}
