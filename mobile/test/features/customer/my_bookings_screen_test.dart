import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:mobile/features/customer/application/booking_controller.dart';
import 'package:mobile/features/customer/application/browse_controller.dart';
import 'package:mobile/features/customer/application/review_controller.dart';
import 'package:mobile/features/customer/data/bookings_repository.dart';
import 'package:mobile/features/customer/data/review_repository.dart';
import 'package:mobile/features/customer/domain/booking.dart';
import 'package:mobile/features/customer/domain/public_business.dart';
import 'package:mobile/features/customer/domain/review.dart';
import 'package:mobile/features/customer/presentation/my_bookings_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Nothing written offline.
class _NoOutbox extends ReviewOutbox {
  @override
  Future<List<Review>> build() async => [];
}

void main() {
  const shop = PublicBusiness(id: 'shop-1', ownerId: 'o1', name: 'Fresh Cuts', currency: 'GBP');
  const me = Profile(id: 'me-1', role: AccountRole.customer, username: 'me', referralCode: 'MYCODE01');
  final bookings = [
    for (var i = 0; i < 50; i++)
      Booking(
        id: 'b$i',
        businessId: 'shop-1',
        workerId: 'w1',
        serviceId: 's1',
        customerId: 'me-1',
        startTime: DateTime.utc(2026, 9, 1).add(Duration(days: i)),
        endTime: DateTime.utc(2026, 9, 1, 1).add(Duration(days: i)),
        status: BookingStatus.completed,
      ),
  ];

  testWidgets('50 completed bookings load with one bookings query and one reviews query', (tester) async {
    final bookingsRepository = _CountingBookings(bookings);
    // Every other booking already reviewed.
    final reviewRepository = _CountingReviews({for (var i = 0; i < 50; i += 2) 'b$i'});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => me),
        bookingsRepositoryProvider.overrideWithValue(bookingsRepository),
        reviewRepositoryProvider.overrideWithValue(reviewRepository),
        reviewOutboxProvider.overrideWith(_NoOutbox.new),
        bookingsAtRiskProvider.overrideWith((ref) async => {}),
        businessProvider.overrideWith((ref, id) async => shop),
      ],
      child: const MaterialApp(home: MyBookingsScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();
    // Scroll through, so every row is built.
    await tester.dragUntilVisible(find.text('Reviewed').last, find.byType(ListView), const Offset(0, -500));
    await tester.fling(find.byType(ListView), const Offset(0, -20000), 5000);
    await tester.pumpAndSettle();

    expect(bookingsRepository.calls + reviewRepository.calls, 2);
    expect(find.text('Leave a review'), findsWidgets);
    expect(find.text('Reviewed'), findsWidgets);
  });

  testWidgets('a booking its shop will be deleted before shows when it will be cancelled', (tester) async {
    final cancelledAt = DateTime.now().add(const Duration(days: 20));
    final upcoming = Booking(
      id: 'up-1',
      businessId: 'shop-1',
      workerId: 'w1',
      serviceId: 's1',
      customerId: 'me-1',
      startTime: DateTime.now().add(const Duration(days: 40)),
      endTime: DateTime.now().add(const Duration(days: 40, hours: 1)),
      status: BookingStatus.confirmed,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => me),
        bookingsRepositoryProvider.overrideWithValue(_CountingBookings([upcoming])),
        reviewRepositoryProvider.overrideWithValue(_CountingReviews({})),
        reviewOutboxProvider.overrideWith(_NoOutbox.new),
        bookingsAtRiskProvider.overrideWith((ref) async => {'up-1': cancelledAt}),
        businessProvider.overrideWith((ref, id) async => shop),
      ],
      child: const MaterialApp(home: MyBookingsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text(shopClosureNotice(lookupAppLocalizations(const Locale('en')), cancelledAt, DateTime.now())), findsOneWidget);
    expect(find.textContaining('this booking will be cancelled.'), findsOneWidget);
  });

  testWidgets('upcoming bookings come soonest first and say what they are', (tester) async {
    Booking upcoming(String id, int days) => Booking(
          id: id,
          businessId: 'shop-1',
          workerId: 'w1',
          serviceId: 's1',
          customerId: 'me-1',
          startTime: DateTime.now().add(Duration(days: days)),
          endTime: DateTime.now().add(Duration(days: days, minutes: 30)),
          status: BookingStatus.confirmed,
          serviceName: days == 2 ? 'Skin fade' : 'Beard trim',
          workerName: 'Sam',
          priceCents: 1500,
        );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => me),
        // Newest first, as the repository returns them.
        bookingsRepositoryProvider.overrideWithValue(_CountingBookings([upcoming('later', 9), upcoming('soon', 2)])),
        reviewRepositoryProvider.overrideWithValue(_CountingReviews({})),
        reviewOutboxProvider.overrideWith(_NoOutbox.new),
        bookingsAtRiskProvider.overrideWith((ref) async => {}),
        businessProvider.overrideWith((ref, id) async => shop),
      ],
      child: const MaterialApp(home: MyBookingsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Fresh Cuts'), findsNWidgets(2));
    final soon = tester.getTopLeft(find.textContaining('Skin fade · with Sam · 30 min · £15'));
    final later = tester.getTopLeft(find.textContaining('Beard trim'));
    expect(soon.dy, lessThan(later.dy));
  });

  test('the notice is reworded for the last day', () {
    final now = DateTime.utc(2026, 4, 1, 13);
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(shopClosureNotice(l10n, DateTime.utc(2026, 4, 2, 12), now), contains('within a day'));
    expect(shopClosureNotice(l10n, DateTime.utc(2026, 4, 2, 12), now.subtract(const Duration(days: 5))), contains('Apr 2'));
  });
}

class _CountingBookings extends Fake implements BookingsRepository {
  _CountingBookings(this.bookings);

  final List<Booking> bookings;
  int calls = 0;

  @override
  Future<List<Booking>> fetchMyBookings(String customerId) async {
    calls++;
    return bookings;
  }
}

class _CountingReviews extends Fake implements ReviewRepository {
  _CountingReviews(this.reviewed);

  final Set<String> reviewed;
  int calls = 0;

  Review _review(String bookingId) =>
      Review(bookingId: bookingId, businessId: 'shop-1', workerId: 'w1', customerId: 'me-1');

  @override
  Future<Map<String, Review>> fetchReviewsByCustomer(String customerId) async {
    calls++;
    return {for (final bookingId in reviewed) bookingId: _review(bookingId)};
  }
}
