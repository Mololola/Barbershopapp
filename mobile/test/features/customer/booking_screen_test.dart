import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/business/domain/business.dart';
import 'package:mobile/features/customer/application/booking_controller.dart';
import 'package:mobile/features/customer/application/browse_controller.dart';
import 'package:mobile/features/customer/presentation/booking_screen.dart';

void main() {
  const businessId = 'biz-1';
  const serviceId = 'service-1';
  const worker = Worker(id: 'worker-1', businessId: businessId, name: 'Luis');
  final slot = DateTime.utc(2026, 8, 3, 9, 0);

  Widget buildTestable() {
    return ProviderScope(
      overrides: [
        businessWorkersProvider.overrideWith((ref, id) async => [worker]),
        availabilityProvider.overrideWith((ref, query) async => [slot]),
      ],
      child: const MaterialApp(
        home: BookingScreen(businessId: businessId, serviceId: serviceId),
      ),
    );
  }

  testWidgets('confirm button is disabled until a slot is selected', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm booking'));
    expect(button.onPressed, isNull);
  });

  testWidgets('selecting a slot enables the confirm button', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ChoiceChip).first);
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm booking'));
    expect(button.onPressed, isNotNull);
  });
}
