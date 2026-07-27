import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/business/application/business_controller.dart';
import 'package:mobile/features/business/domain/business.dart';
import 'package:mobile/features/business/presentation/business_edit_screen.dart';
import 'package:mobile/features/business/presentation/services_screen.dart';
import 'package:mobile/features/business/presentation/staff_screen.dart';
import 'package:mobile/features/worker/domain/worker_invitation.dart';

void main() {
  const business = Business(id: 'biz-1', ownerId: 'owner-1', name: 'Fresh Cuts', currency: 'GBP');

  Widget buildTestable() {
    final router = GoRouter(
      initialLocation: '/business/edit',
      routes: [
        GoRoute(path: '/business/edit', builder: (context, state) => const BusinessEditScreen()),
        GoRoute(path: '/business/services', builder: (context, state) => const ServicesScreen()),
        GoRoute(path: '/business/staff', builder: (context, state) => const StaffScreen()),
      ],
    );
    return ProviderScope(
      overrides: [
        currentBusinessProvider.overrideWith((ref) async => business),
        locationsProvider.overrideWith((ref) async => <BusinessLocation>[]),
        servicesProvider.overrideWith((ref) async => <Service>[]),
        workersProvider.overrideWith((ref) async => <Worker>[]),
        sentInvitationsProvider.overrideWith((ref) async => <WorkerInvitation>[]),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('"Manage services" navigates to the services screen', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manage services'));
    await tester.pumpAndSettle();

    expect(find.text('No services yet — add your first one.'), findsOneWidget);
  });

  testWidgets('"Manage staff" navigates to the staff screen', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Manage staff'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Manage staff'));
    await tester.pumpAndSettle();

    expect(find.text('No staff yet — add your first team member.'), findsOneWidget);
  });
}
