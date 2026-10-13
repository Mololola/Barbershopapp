import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:mobile/features/customer/application/booking_controller.dart';
import 'package:mobile/features/customer/application/review_controller.dart';
import 'package:mobile/features/customer/data/bookings_repository.dart';
import 'package:mobile/features/customer/data/review_repository.dart';
import 'package:mobile/features/customer/domain/booking.dart';
import 'package:mobile/features/customer/domain/review.dart';
import 'package:mobile/features/customer/presentation/my_bookings_screen.dart';

void main() {
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
        bookingsAtRiskProvider.overrideWith((ref) async => {}),
      ],
      child: const MaterialApp(home: MyBookingsScreen()),
    ));
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
        bookingsAtRiskProvider.overrideWith((ref) async => {'up-1': cancelledAt}),
      ],
      child: const MaterialApp(home: MyBookingsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text(shopClosureNotice(cancelledAt, DateTime.now())), findsOneWidget);
    expect(find.textContaining('this booking will be cancelled.'), findsOneWidget);
  });

  test('the notice is reworded for the last day', () {
    final now = DateTime.utc(2026, 4, 1, 13);
    expect(shopClosureNotice(DateTime.utc(2026, 4, 2, 12), now), contains('within a day'));
    expect(shopClosureNotice(DateTime.utc(2026, 4, 2, 12), now.subtract(const Duration(days: 5))), contains('2 Apr'));
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
