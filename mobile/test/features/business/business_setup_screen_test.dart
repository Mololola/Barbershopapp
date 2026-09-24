import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/business/application/business_controller.dart';
import 'package:mobile/features/business/domain/business.dart';
import 'package:mobile/features/business/presentation/business_setup_screen.dart';
import 'package:mobile/features/worker/domain/worker_invitation.dart';

void main() {
  const business = Business(id: 'biz-1', ownerId: 'owner-1', name: 'Fresh Cuts', currency: 'GBP');
  const service = Service(id: 's1', businessId: 'biz-1', name: 'Fade', priceCents: 1500, durationMinutes: 30);

  Widget buildTestable({Business? currentBusiness, List<Service> services = const [], List<Worker> workers = const []}) {
    return ProviderScope(
      overrides: [
        currentBusinessProvider.overrideWith((ref) async => currentBusiness),
        signUpBusinessNameProvider.overrideWithValue('Fresh Cuts'),
        servicesProvider.overrideWith((ref) async => services),
        workersProvider.overrideWith((ref) async => workers),
        sentInvitationsProvider.overrideWith((ref) async => <WorkerInvitation>[]),
      ],
      child: const MaterialApp(home: BusinessSetupScreen()),
    );
  }

  FilledButton buttonLabelled(WidgetTester tester, String label) {
    return tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));
  }

  testWidgets('details step: shows validation errors when submitted empty', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    // The form's ListView only builds children near the viewport, so scroll
    // the submit button into view before tapping it.
    await tester.scrollUntilVisible(
      find.text('Save and continue'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save and continue'));
    await tester.pump();

    expect(find.text('Required'), findsWidgets);
  });

  testWidgets('details step: pre-fills the business name given at sign-up', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Fresh Cuts'), findsOneWidget);
  });

  testWidgets('details step: starts with one location row and can add another', (tester) async {
    // Phone width (360dp): also guards the opening-hours rows against overflow.
    tester.view.physicalSize = const Size(1080, 6000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('Street address'), findsOneWidget);
    expect(find.text('Postcode'), findsOneWidget);

    await tester.tap(find.text('Add another location'));
    await tester.pump();

    expect(find.text('Postcode'), findsNWidgets(2));
  });

  testWidgets('services step: Continue is disabled until a service exists', (tester) async {
    await tester.pumpWidget(buildTestable(currentBusiness: business));
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(buttonLabelled(tester, 'Continue').onPressed, isNull);
  });

  testWidgets('resumes on the staff step once a service exists, with Finish disabled until staff exist',
      (tester) async {
    await tester.pumpWidget(buildTestable(currentBusiness: business, services: [service]));
    await tester.pumpAndSettle();

    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(buttonLabelled(tester, 'Finish').onPressed, isNull);
  });

  testWidgets('staff step: Finish is enabled once an active staff member exists', (tester) async {
    await tester.pumpWidget(buildTestable(
      currentBusiness: business,
      services: [service],
      workers: [const Worker(id: 'w1', businessId: 'biz-1', name: 'Luis')],
    ));
    await tester.pumpAndSettle();

    expect(buttonLabelled(tester, 'Finish').onPressed, isNotNull);
  });
}
