import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/customer/application/booking_controller.dart';
import 'package:mobile/features/customer/domain/booking.dart';
import 'package:mobile/features/customer/presentation/booking_screen.dart';

void main() {
  const businessId = 'biz-1';
  const serviceId = 'service-1';
  final slotA = AvailableSlot(workerId: 'worker-a', workerName: 'Jane', startTime: DateTime.utc(2026, 8, 3, 9, 0));
  final slotB = AvailableSlot(workerId: 'worker-b', workerName: 'Mike', startTime: DateTime.utc(2026, 8, 3, 9, 0));

  Widget buildTestable(List<AvailableSlot> slots) {
    return ProviderScope(
      overrides: [
        availabilityProvider.overrideWith((ref, query) async => slots),
      ],
      child: const MaterialApp(
        home: BookingScreen(businessId: businessId, serviceId: serviceId),
      ),
    );
  }

  FilledButton confirmButton(WidgetTester tester) => tester.widget<FilledButton>(find.byType(FilledButton));

  testWidgets('confirm button is disabled until a time is selected', (tester) async {
    await tester.pumpWidget(buildTestable([slotA]));
    await tester.pumpAndSettle();

    expect(confirmButton(tester).onPressed, isNull);
  });

  testWidgets('selecting a time enables confirm and names the barber', (tester) async {
    await tester.pumpWidget(buildTestable([slotA]));
    await tester.pumpAndSettle();

    // Chips: "Any barber", "Jane", then the times.
    await tester.tap(find.byType(ChoiceChip).last);
    await tester.pumpAndSettle();

    expect(confirmButton(tester).onPressed, isNotNull);
    expect(find.textContaining('with Jane'), findsOneWidget);
  });

  testWidgets('"Any barber" shows each time once; picking a barber shows theirs', (tester) async {
    final laterB =
        AvailableSlot(workerId: 'worker-b', workerName: 'Mike', startTime: DateTime.utc(2026, 8, 3, 9, 15));
    await tester.pumpWidget(buildTestable([slotA, slotB, laterB]));
    await tester.pumpAndSettle();

    // Any barber, Jane, Mike + two distinct times (9:00 shared, 9:15 Mike only).
    expect(find.byType(ChoiceChip), findsNWidgets(5));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Mike'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ChoiceChip).last);
    await tester.pumpAndSettle();

    expect(find.textContaining('with Mike'), findsOneWidget);
  });
}
