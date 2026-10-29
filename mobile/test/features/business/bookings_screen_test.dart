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

  testWidgets('only a booking that has started can be marked done', (tester) async {
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
    expect(find.text('jordan'), findsNWidgets(2));
  });
}
