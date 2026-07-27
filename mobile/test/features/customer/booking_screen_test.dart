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

  testWidgets('confirm button is disabled until a slot is selected', (tester) async {
    await tester.pumpWidget(buildTestable([slotA]));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm booking'));
    expect(button.onPressed, isNull);
  });

  testWidgets('selecting a slot enables the confirm button', (tester) async {
    await tester.pumpWidget(buildTestable([slotA]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ChoiceChip).first);
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm booking'));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('two workers free at the same time render as two distinct slots', (tester) async {
    await tester.pumpWidget(buildTestable([slotA, slotB]));
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsNWidgets(2));
    expect(find.textContaining('Jane'), findsOneWidget);
    expect(find.textContaining('Mike'), findsOneWidget);
  });
}
