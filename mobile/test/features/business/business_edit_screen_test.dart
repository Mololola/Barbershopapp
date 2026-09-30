import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/business/application/business_controller.dart';
import 'package:mobile/features/business/domain/business.dart';
import 'package:mobile/features/business/presentation/business_edit_screen.dart';
import 'package:mobile/features/business/presentation/services_screen.dart';
import 'package:mobile/features/worker/domain/worker_invitation.dart';

void main() {
  const business = Business(id: 'biz-1', ownerId: 'owner-1', name: 'Fresh Cuts', currency: 'GBP');

  Widget buildTestable() {
    final router = GoRouter(
      initialLocation: '/business/edit',
      routes: [
        GoRoute(path: '/business/edit', builder: (context, state) => const BusinessEditScreen()),
        GoRoute(path: '/business/services', builder: (context, state) => const ServicesScreen()),
      ],
    );
    return ProviderScope(
      overrides: [
        currentBusinessProvider.overrideWith((ref) async => business),
        locationsProvider.overrideWith((ref) async => <BusinessLocation>[]),
        openingHoursProvider.overrideWith((ref) async => <OpeningHours>[]),
        servicesProvider.overrideWith((ref) async => <Service>[]),
        workersProvider.overrideWith((ref) async => <Worker>[]),
        sentInvitationsProvider.overrideWith((ref) async => <WorkerInvitation>[]),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('edits opening hours, including adding a break', (tester) async {
    tester.view.physicalSize = const Size(1080, 8000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('Opening hours'), findsOneWidget);
    expect(find.text('Break'), findsNothing);

    await tester.tap(find.text('Add break').first);
    await tester.pump();

    expect(find.text('Break'), findsOneWidget);
  });

  testWidgets('does not offer a "Manage staff" shortcut (Staff has its own bottom-nav tab)', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('Manage staff'), findsNothing);
  });
}
