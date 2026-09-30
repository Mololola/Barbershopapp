import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:mobile/features/auth/presentation/account_settings_screen.dart';
import 'package:mobile/features/worker/application/worker_controller.dart';
import 'package:mobile/features/worker/domain/worker_invitation.dart';
import 'package:mobile/features/worker/presentation/worker_profile_screen.dart';

void main() {
  const profile =
      Profile(id: 'me-1', role: AccountRole.customer, username: 'me', referralCode: 'MYCODE01');

  Widget buildTestable() {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (context, state) => const AccountSettingsScreen()),
        GoRoute(
          path: '/customer/worker-profile',
          builder: (context, state) => const WorkerProfileScreen(),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => profile),
        currentWorkerProfileProvider.overrideWith((ref) async => null),
        receivedInvitationsProvider.overrideWith((ref) async => <WorkerInvitation>[]),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('Settings > "Worker profile" navigates to the worker profile screen', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Worker profile'));
    await tester.pumpAndSettle();

    expect(find.text('Available as worker'), findsOneWidget);
  });

  testWidgets('Settings shows the referral code', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('MYCODE01'), findsOneWidget);
  });
}
