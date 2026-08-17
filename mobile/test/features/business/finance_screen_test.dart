import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/business/application/business_controller.dart';
import 'package:mobile/features/business/domain/business.dart';
import 'package:mobile/features/business/domain/business_finance_access.dart';
import 'package:mobile/features/business/presentation/finance_screen.dart';
import 'package:mobile/features/customer/domain/booking.dart';

void main() {
  const business = Business(id: 'biz-1', ownerId: 'owner-1', name: 'Cuts Co', currency: 'GBP');
  const service = Service(id: 'svc-1', businessId: 'biz-1', name: 'Cut', priceCents: 2000, durationMinutes: 30);
  const costItem = CostItem(id: 'cost-1', businessId: 'biz-1', label: 'Rent', amountCents: 5000);
  final now = DateTime.now();
  final completedBooking = Booking(
    id: 'b1',
    businessId: 'biz-1',
    workerId: 'worker-1',
    serviceId: 'svc-1',
    customerId: 'cust-1',
    startTime: DateTime(now.year, now.month, 15),
    endTime: DateTime(now.year, now.month, 15, 0, 30),
    status: BookingStatus.completed,
  );

  Widget buildTestable() {
    return ProviderScope(
      overrides: [
        currentBusinessProvider.overrideWith((ref) async => business),
        servicesProvider.overrideWith((ref) async => [service]),
        businessBookingsProvider.overrideWith((ref) async => [completedBooking]),
        costItemsProvider.overrideWith((ref) async => [costItem]),
        financeAccessProvider.overrideWith(
          (ref) async => const BusinessFinanceAccess(grandfathered: true, amountCents: 4500),
        ),
      ],
      child: const MaterialApp(home: FinanceScreen()),
    );
  }

  testWidgets('shows this month\'s revenue/costs/net and the cost item list', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('Revenue: £20.00 (1 haircuts)'), findsOneWidget);
    expect(find.text('1 × Cut: £20.00'), findsOneWidget);
    expect(find.text('Costs: £50.00'), findsOneWidget);
    expect(find.text('Net: -£30.00'), findsOneWidget);
    expect(find.textContaining('short of breaking even'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('£50.00'), findsOneWidget);
  });
}
