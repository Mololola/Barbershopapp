import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_reporting.dart';
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
  final waiting = await ref.watch(reviewOutboxProvider.future);
  return {
    ...await ref.watch(reviewRepositoryProvider).fetchReviewsByCustomer(profile.id),
    for (final review in waiting) review.bookingId: review,
  };
});

/// What the one-time review pop-up on Home asks about.
class ReviewPrompt {
  const ReviewPrompt({required this.booking, required this.mentionsReward});

  final Booking booking;

  /// Only for the customer's first [_rewardPromptCuts] cuts, and only while
  /// the backend would still pay the reward (rewards.py's _REWARD_WINDOW).
  final bool mentionsReward;
}

const _rewardPromptCuts = 4;
const _rewardWindow = Duration(hours: 6);
const _promptsShownKey = 'review-prompts-shown';

/// The newest completed, unreviewed booking whose pop-up hasn't been shown
/// yet, if any — see `customer_home_screen.dart`.
final reviewPromptProvider = FutureProvider<ReviewPrompt?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return null;
  final waiting = {for (final review in await ref.watch(reviewOutboxProvider.future)) review.bookingId};
  final shown = {for (final row in await ref.read(offlineCacheProvider).readList(_promptsShownKey)) row['id']};
  final completed = await ref.watch(bookingsRepositoryProvider).fetchCompletedBookings(profile.id);
  for (var i = completed.length - 1; i >= 0; i--) {
    final (:booking, :reviewed) = completed[i];
    if (reviewed || waiting.contains(booking.id) || shown.contains(booking.id)) continue;
    return ReviewPrompt(
      booking: booking,
      mentionsReward: i < _rewardPromptCuts && DateTime.now().isBefore(booking.endTime.add(_rewardWindow)),
    );
  }
  return null;
});

Future<void> markReviewPromptShown(OfflineCache cache, String bookingId) async {
  final shown = await cache.readList(_promptsShownKey);
  await cache.writeList(_promptsShownKey, [...shown, {'id': bookingId}]);
}

/// Reviews written with no connection, kept on the phone and sent (with
/// their reward) each time this rebuilds: on start, on signing in, and when
/// the connection comes back. Kept alive from main.dart.
class ReviewOutbox extends AsyncNotifier<List<Review>> {
  static const _key = 'outbox:reviews';

  @override
  Future<List<Review>> build() async {
    ref.watch(authStateChangesProvider);
    ref.watch(reconnectsProvider);
    final cache = ref.read(offlineCacheProvider);
    final waiting = [for (final row in await cache.readList(_key)) Review.fromRow(row)];
    final left = <Review>[];
    for (final review in waiting) {
      try {
        await _send(review);
      } catch (error, stack) {
        if (isOfflineError(error)) {
          left.add(review);
        } else {
          reportError(error, stack, context: 'ReviewOutbox');
        }
      }
    }
    if (left.length != waiting.length) {
      await cache.writeList(_key, [for (final review in left) review.toRow()]);
    }
    return left;
  }

  Future<void> _send(Review review) async {
    await ref.read(reviewRepositoryProvider).submitReview(review);
    try {
      await ref.read(bookingApiClientProvider).creditReviewReward(review.bookingId);
      ref.invalidate(rewardBalanceProvider);
    } catch (error) {
      debugPrint('Reward crediting failed for booking ${review.bookingId}: $error');
    }
  }

  Future<void> add(Review review) async {
    final waiting = [...await future, review];
    await ref.read(offlineCacheProvider).writeList(_key, [for (final r in waiting) r.toRow()]);
    state = AsyncData(waiting);
  }
}

final reviewOutboxProvider = AsyncNotifierProvider<ReviewOutbox, List<Review>>(ReviewOutbox.new);

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
      final review = Review(
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
      );
      try {
        await ref.read(reviewRepositoryProvider).submitReview(review);
      } catch (error) {
        if (!isOfflineError(error)) rethrow;
        // Saved on the phone: sent, and its reward credited, once back online.
        ref.read(connectionProvider.notifier).reportOffline();
        await ref.read(reviewOutboxProvider.notifier).add(review);
        success = true;
        return;
      }
      ref.invalidate(myReviewsByBookingProvider);
      ref.invalidate(reviewPromptProvider);
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
