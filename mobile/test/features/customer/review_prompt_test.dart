import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/offline_cache.dart';
import 'package:mobile/core/supabase_providers.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:mobile/features/customer/application/booking_controller.dart';
import 'package:mobile/features/customer/application/review_controller.dart';
import 'package:mobile/features/customer/data/bookings_repository.dart';
import 'package:mobile/features/customer/domain/booking.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeBookings extends Fake implements BookingsRepository {
  _FakeBookings(this.completed);

  final List<({Booking booking, bool reviewed})> completed;

  @override
  Future<List<({Booking booking, bool reviewed})>> fetchCompletedBookings(String customerId) async => completed;
}

Booking _cut(String id, {required Duration endedAgo}) {
  final end = DateTime.now().subtract(endedAgo);
  return Booking(
    id: id,
    customerId: 'me',
    businessId: 'shop',
    workerId: 'w1',
    serviceId: 's1',
    startTime: end.subtract(const Duration(minutes: 30)),
    endTime: end,
    status: BookingStatus.completed,
  );
}

ProviderContainer _container(List<({Booking booking, bool reviewed})> completed) {
  final container = ProviderContainer(
    overrides: [
      currentAuthUserIdProvider.overrideWithValue('me'),
      authStateChangesProvider.overrideWith((ref) => const Stream<AuthState>.empty()),
      currentProfileProvider.overrideWith(
        (ref) async => const Profile(id: 'me', role: AccountRole.customer, username: 'me', referralCode: 'C'),
      ),
      bookingsRepositoryProvider.overrideWithValue(_FakeBookings(completed)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a recent cut among the first 4 mentions the reward', () async {
    final container = _container([(booking: _cut('b1', endedAgo: const Duration(hours: 1)), reviewed: false)]);

    final prompt = await container.read(reviewPromptProvider.future);

    expect(prompt?.booking.id, 'b1');
    expect(prompt?.mentionsReward, isTrue);
  });

  test('the 5th cut gets a plain reminder', () async {
    final container = _container([
      for (var i = 1; i <= 4; i++) (booking: _cut('b$i', endedAgo: Duration(days: 10 - i)), reviewed: true),
      (booking: _cut('b5', endedAgo: const Duration(hours: 1)), reviewed: false),
    ]);

    final prompt = await container.read(reviewPromptProvider.future);

    expect(prompt?.booking.id, 'b5');
    expect(prompt?.mentionsReward, isFalse);
  });

  test('no reward is mentioned once the 6 hours have passed', () async {
    final container = _container([(booking: _cut('b1', endedAgo: const Duration(hours: 7)), reviewed: false)]);

    expect((await container.read(reviewPromptProvider.future))?.mentionsReward, isFalse);
  });

  test('a cut is only asked about once, and reviewed cuts never', () async {
    final container = _container([
      (booking: _cut('b1', endedAgo: const Duration(days: 2)), reviewed: false),
      (booking: _cut('b2', endedAgo: const Duration(days: 1)), reviewed: true),
    ]);

    expect((await container.read(reviewPromptProvider.future))?.booking.id, 'b1');
    await markReviewPromptShown(container.read(offlineCacheProvider), 'b1');
    container.invalidate(reviewPromptProvider);
    expect(await container.read(reviewPromptProvider.future), isNull);
  });
}
