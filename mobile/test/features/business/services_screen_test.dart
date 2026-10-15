import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/business/application/business_controller.dart';
import 'package:mobile/features/business/domain/business.dart';
import 'package:mobile/features/business/presentation/services_screen.dart';

void main() {
  const business = Business(id: 'biz-1', ownerId: 'owner-1', name: 'Fresh Cuts', currency: 'GBP');
  const haircut =
      Service(id: 's1', businessId: 'biz-1', name: 'Haircut', priceCents: 1500, durationMinutes: 30, isBasicCut: true);
  const beard = Service(id: 's2', businessId: 'biz-1', name: 'Beard', priceCents: 800, durationMinutes: 20);

  Widget buildTestable(List<Service> services) => ProviderScope(
        overrides: [
          currentBusinessProvider.overrideWith((ref) async => business),
          servicesProvider.overrideWith((ref) async => services),
        ],
        child: const MaterialApp(home: ServicesScreen()),
      );

  testWidgets('a shop with no services is asked for its basic cut first', (tester) async {
    await tester.pumpWidget(buildTestable([]));
    await tester.pumpAndSettle();

    expect(find.text('Add your basic cut'), findsOneWidget);
    await tester.tap(find.text('Add your basic cut'));
    await tester.pumpAndSettle();
    expect(find.text('Your basic cut'), findsOneWidget);
    expect(find.text('Your standard haircut, with its price and duration.'), findsOneWidget);
  });

  testWidgets('the basic cut is marked, and can\'t be removed while other services exist', (tester) async {
    await tester.pumpWidget(buildTestable([haircut, beard]));
    await tester.pumpAndSettle();

    expect(find.text('Basic cut'), findsOneWidget);
    await tester.tap(find.byTooltip('Service options').first);
    await tester.pumpAndSettle();
    expect(find.text('Make basic cut'), findsNothing);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Your shop needs a basic cut'), findsOneWidget);
  });

  testWidgets('removing another service keeps its bookings', (tester) async {
    await tester.pumpWidget(buildTestable([haircut, beard]));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Service options').last);
    await tester.pumpAndSettle();
    expect(find.text('Make basic cut'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Remove Beard?'), findsOneWidget);
    expect(find.textContaining('Bookings already made for it are kept.'), findsOneWidget);
  });
}
