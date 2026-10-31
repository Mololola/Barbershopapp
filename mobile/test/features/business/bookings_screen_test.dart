import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/business/application/business_controller.dart';
import 'package:mobile/features/business/presentation/bookings_screen.dart';
import 'package:mobile/features/customer/domain/booking.dart';

void main() {
  Booking booking(String id, DateTime start) => Booking(
        id: id,
        businessId: 'shop-1',
        workerId: 'w1',
        serviceId: 's1',
        customerId: 'c1',
        startTime: start,
        endTime: start.add(const Duration(minutes: 30)),
        status: BookingStatus.confirmed,
        customerName: 'jordan',
      );

  testWidgets('only a booking that has started can be marked done or a no-show', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        businessBookingsProvider.overrideWith((ref) async => [
              booking('started', now.subtract(const Duration(minutes: 10))),
              booking('later', now.add(const Duration(hours: 2))),
            ]),
      ],
      child: const MaterialApp(home: BookingsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Confirmed'), findsNWidgets(2));
    expect(find.text('Mark as done'), findsOneWidget);
    expect(find.text('No-show'), findsOneWidget);
    expect(find.text('jordan'), findsNWidgets(2));
  });

  testWidgets("on the website a day's bookings sit side by side; on a phone they stack", (tester) async {
    final later = DateTime.now().add(const Duration(days: 1));
    final day = DateTime(later.year, later.month, later.day, 10);
    Future<void> pumpAt(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          businessBookingsProvider.overrideWith((ref) async => [
                booking('a', day),
                booking('b', day.add(const Duration(hours: 1))),
              ]),
        ],
        child: const MaterialApp(home: BookingsScreen()),
      ));
      await tester.pumpAndSettle();
    }
    addTearDown(tester.view.reset);

    await pumpAt(const Size(1280, 800));
    final cards = find.byType(Card);
    expect(tester.getTopLeft(cards.at(0)).dy, tester.getTopLeft(cards.at(1)).dy);

    await pumpAt(const Size(400, 800));
    expect(tester.getTopLeft(cards.at(0)).dy, lessThan(tester.getTopLeft(cards.at(1)).dy));
  });
}
