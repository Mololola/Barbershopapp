import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/offline_cache.dart';
import 'package:mobile/core/supabase_providers.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:mobile/features/customer/application/booking_controller.dart';
import 'package:mobile/features/customer/application/review_controller.dart';
import 'package:mobile/features/customer/data/booking_api_client.dart';
import 'package:mobile/features/customer/data/bookings_repository.dart';
import 'package:mobile/features/customer/data/review_repository.dart';
import 'package:mobile/features/customer/domain/booking.dart';
import 'package:mobile/features/customer/domain/review.dart';
import 'package:mobile/features/rewards/domain/reward_credit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeReviews extends Fake implements ReviewRepository {
  bool online = false;
  final submitted = <String>[];

  @override
  Future<void> submitReview(Review review) async {
    if (!online) throw http.ClientException('no connection');
    submitted.add(review.bookingId);
  }

  @override
  Future<Map<String, Review>> fetchReviewsByCustomer(String customerId) async => {};
}

class _FakeBookings extends Fake implements BookingsRepository {
  @override
  Future<Booking?> fetchOldestUnreviewedCompletedBooking(String customerId, {Set<String> except = const {}}) async =>
      except.contains('b1') ? null : _booking;
}

class _FakeBookingApi extends Fake implements BookingApiClient {
  final credited = <String>[];

  @override
  Future<RewardCredit> creditReviewReward(String bookingId) async {
    credited.add(bookingId);
    throw http.ClientException('not needed here');
  }
}

final _booking = Booking(
  id: 'b1',
  customerId: 'me',
  businessId: 'shop',
  workerId: 'w1',
  serviceId: 's1',
  startTime: DateTime.utc(2026, 10, 1, 10),
  endTime: DateTime.utc(2026, 10, 1, 10, 30),
  status: BookingStatus.completed,
);

void main() {
  test('a review written offline stops the review prompt, then is sent with its reward once online', () async {
    SharedPreferences.setMockInitialValues({});
    final reviews = _FakeReviews();
    final api = _FakeBookingApi();
    final container = ProviderContainer(
      overrides: [
        currentAuthUserIdProvider.overrideWithValue('me'),
        authStateChangesProvider.overrideWith((ref) => const Stream<AuthState>.empty()),
        currentProfileProvider.overrideWith(
          (ref) async => const Profile(id: 'me', role: AccountRole.customer, username: 'me', referralCode: 'C'),
        ),
        reviewRepositoryProvider.overrideWithValue(reviews),
        bookingsRepositoryProvider.overrideWithValue(_FakeBookings()),
        bookingApiClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    container.listen(reviewOutboxProvider, (_, _) {});
    expect((await container.read(pendingReviewProvider.future))?.id, 'b1');

    final success = await container
        .read(reviewControllerProvider.notifier)
        .submit(bookingId: 'b1', businessId: 'shop', workerId: 'w1', shopRating: 5);
    expect(success, isTrue);
    expect(await container.read(pendingReviewProvider.future), isNull);
    expect((await container.read(myReviewsByBookingProvider.future)).keys, ['b1']);

    reviews.online = true;
    container.read(connectionProvider.notifier).reportOnline();
    expect(await container.read(reviewOutboxProvider.future), isEmpty);
    expect(reviews.submitted, ['b1']);
    expect(api.credited, ['b1']);
  });
}
