import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/business/application/business_controller.dart';
import 'package:mobile/features/business/domain/business.dart';
import 'package:mobile/features/business/presentation/business_home_screen.dart';

void main() {
  const business = Business(id: 'biz-1', ownerId: 'owner-1', name: 'Fresh Cuts', currency: 'GBP');
  final service = Service(
    id: 's1',
    businessId: 'biz-1',
    name: 'Haircut',
    priceCents: 2000,
    durationMinutes: 30,
  );
  const worker = Worker(businessId: 'biz-1', businessName: 'Fresh Cuts', name: 'Jane Doe');

  Widget buildTestable() {
    return ProviderScope(
      overrides: [
        currentBusinessProvider.overrideWith((ref) async => business),
        locationsProvider.overrideWith((ref) async => <BusinessLocation>[]),
        openingHoursProvider.overrideWith((ref) async => <OpeningHours>[]),
        servicesProvider.overrideWith((ref) async => [service]),
        workersProvider.overrideWith((ref) async => [worker]),
      ],
      child: const MaterialApp(home: BusinessHomeScreen()),
    );
  }

  testWidgets('shows services and staff, edit icon, and no management buttons', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.textContaining('Haircut'), findsOneWidget);
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

    expect(find.text('Manage services'), findsNothing);
    expect(find.text('Manage staff'), findsNothing);
    expect(find.text('Profile'), findsNothing);
  });
}
