import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/business/application/business_controller.dart';
import 'package:mobile/features/business/domain/business.dart';
import 'package:mobile/features/business/presentation/business_home_screen.dart';
import 'package:mobile/features/customer/domain/booking.dart';
import 'package:mobile/features/messaging/application/messaging_controller.dart';

void main() {
  const business = Business(id: 'biz-1', ownerId: 'owner-1', name: 'Fresh Cuts', currency: 'GBP');
  final service = Service(
    id: 's1',
    businessId: 'biz-1',
    name: 'Haircut',
    priceCents: 2000,
    durationMinutes: 30,
  );
  const worker = Worker(id: 'w1', businessId: 'biz-1', businessName: 'Fresh Cuts', name: 'Jane Doe');
  final nextStart = DateTime.now().add(const Duration(hours: 2));
  final upcoming = Booking(
    id: 'b1',
    businessId: 'biz-1',
    workerId: 'w1',
    serviceId: 's1',
    customerId: 'c1',
    startTime: nextStart,
    endTime: nextStart.add(const Duration(minutes: 30)),
    status: BookingStatus.confirmed,
  );

  Widget buildTestable() {
    return ProviderScope(
      overrides: [
        currentBusinessProvider.overrideWith((ref) async => business),
        locationsProvider.overrideWith((ref) async => <BusinessLocation>[]),
        openingHoursProvider.overrideWith((ref) async => <OpeningHours>[]),
        servicesProvider.overrideWith((ref) async => [service]),
        workersProvider.overrideWith((ref) async => [worker]),
        businessBookingsProvider.overrideWith((ref) async => [upcoming]),
        autoCompletedToCheckProvider.overrideWith((ref) async => []),
        conversationsProvider.overrideWith((ref) async => []),
      ],
      child: const MaterialApp(home: BusinessHomeScreen()),
    );
  }

  testWidgets('shows services and staff, one settings icon, and no management buttons', (tester) async {
    // Phone width, tall enough to lay out the whole (lazily built) list.
    tester.view.physicalSize = const Size(1080, 6000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.textContaining('Haircut'), findsWidgets);
    expect(find.text('Jane Doe'), findsOneWidget);
    // Everything account/shop-related lives behind the single ⚙️.
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);

    expect(find.text('Manage services'), findsNothing);
    expect(find.text('Manage staff'), findsNothing);
    expect(find.text('Profile'), findsNothing);
  });

  testWidgets('shows the next booking with its barber and service', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('Next booking'), findsOneWidget);
    expect(find.text('with Jane Doe · Haircut'), findsOneWidget);
  });

  testWidgets('no quick actions: messages top right, finance as a home card', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('Quick actions'), findsNothing);
    expect(find.byTooltip('Messages'), findsOneWidget);
    expect(find.text('Finance'), findsOneWidget);
  });
}
