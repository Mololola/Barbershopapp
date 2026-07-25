import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/customer/application/booking_controller.dart';
import 'package:mobile/features/customer/domain/booking.dart';
import 'package:mobile/features/customer/presentation/review_screen.dart';

void main() {
  const bookingId = 'booking-1';
  final booking = Booking(
    id: bookingId,
    businessId: 'biz-1',
    workerId: 'worker-1',
    serviceId: 'service-1',
    customerId: 'customer-1',
    startTime: DateTime.utc(2026, 8, 3, 9, 0),
    endTime: DateTime.utc(2026, 8, 3, 9, 30),
    status: BookingStatus.completed,
  );

  Widget buildTestable() {
    return ProviderScope(
      overrides: [
        bookingProvider.overrideWith((ref, id) async => booking),
      ],
      child: const MaterialApp(home: ReviewScreen(bookingId: bookingId)),
    );
  }

  FilledButton nextButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  testWidgets('one step is shown at a time, starting with the shop', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('Rate the shop'), findsOneWidget);
    expect(find.text('Rate the barber'), findsNothing);
    expect(find.text('Rate the haircut'), findsNothing);
  });

  testWidgets('Next is disabled until a rating is given, then advances to the next step', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(nextButton(tester).onPressed, isNull);

    await tester.tap(find.byIcon(Icons.star_border).first);
    await tester.pump();
    expect(nextButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Rate the barber'), findsOneWidget);
  });

  testWidgets('Omit asks for confirmation and skipping advances without a rating', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Omit'));
    await tester.pumpAndSettle();

    expect(find.text('Skip this rating?'), findsOneWidget);

    await tester.tap(find.text('Skip anyway'));
    await tester.pumpAndSettle();

    expect(find.text('Rate the barber'), findsOneWidget);
  });

  testWidgets('the haircut step includes a haircut-type dropdown', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    // Omit through shop and barber to reach the haircut step.
    await tester.tap(find.text('Omit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip anyway'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Omit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip anyway'));
    await tester.pumpAndSettle();

    expect(find.text('Rate the haircut'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('Submit review'), findsOneWidget);
  });
}
