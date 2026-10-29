import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline_cache.dart';
import '../../../core/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../rewards/application/rewards_controller.dart';
import '../data/review_repository.dart';
import '../domain/booking.dart';
import '../domain/review.dart';
import 'booking_controller.dart' show bookingApiClientProvider, bookingsRepositoryProvider;

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(ref.watch(supabaseClientProvider), ref.watch(offlineCacheProvider));
});

/// My reviews by booking id — one query for the whole My bookings list
/// rather than one per booking.
final myReviewsByBookingProvider = FutureProvider<Map<String, Review>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return {};
  return ref.watch(reviewRepositoryProvider).fetchReviewsByCustomer(profile.id);
});

/// The next completed-but-unreviewed booking to prompt for, if any — see
/// `customer_home_screen.dart`, which checks this once on open.
final pendingReviewProvider = FutureProvider<Booking?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return null;
  return ref.watch(bookingsRepositoryProvider).fetchOldestUnreviewedCompletedBooking(profile.id);
});

final reviewControllerProvider = AsyncNotifierProvider<ReviewController, void>(ReviewController.new);

class ReviewController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Every rating/comment is optional — the step-by-step flow in
  /// `review_screen.dart` lets the customer omit any of the three. One row
  /// is still written so they aren't re-prompted for this booking again.
  /// Returns whether it succeeded — state carries the error either way.
  Future<bool> submit({
    required String bookingId,
    required String businessId,
    required String workerId,
    int? shopRating,
    String? shopComment,
    int? workerRating,
    String? workerComment,
    int? haircutRating,
    String? haircutComment,
    String? haircutType,
  }) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      final profile = await ref.read(currentProfileProvider.future);
      if (profile == null) throw StateError('No signed-in profile.');
      await ref.read(reviewRepositoryProvider).submitReview(
            Review(
              bookingId: bookingId,
              businessId: businessId,
              workerId: workerId,
              customerId: profile.id,
              shopRating: shopRating,
              shopComment: shopComment,
              workerRating: workerRating,
              workerComment: workerComment,
              haircutRating: haircutRating,
              haircutComment: haircutComment,
              haircutType: haircutType,
            ),
          );
      ref.invalidate(myReviewsByBookingProvider);
      ref.invalidate(pendingReviewProvider);
      // Router's redirect gate reads pendingReviewProvider synchronously
      // right after this returns (see core/router.dart) — without awaiting
      // the refresh here, that read can still see the pre-invalidation
      // value and route straight back into reviewing this same booking.
      await ref.read(pendingReviewProvider.future);
      success = true;

      // Best-effort: the review itself already succeeded above, so a
      // failure crediting the reward (or a legitimate non-credit, e.g. the
      // monthly cap) shouldn't surface as an error on this flow.
      try {
        await ref.read(bookingApiClientProvider).creditReviewReward(bookingId);
        ref.invalidate(rewardBalanceProvider);
      } catch (error) {
        debugPrint('Reward crediting failed for booking $bookingId: $error');
      }
    });
    return success;
  }
}
