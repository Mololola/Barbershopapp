import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:mobile/features/auth/presentation/account_settings_screen.dart';

void main() {
  Widget buildTestable(Profile profile) {
    return ProviderScope(
      overrides: [currentProfileProvider.overrideWith((ref) async => profile)],
      child: const MaterialApp(home: AccountSettingsScreen()),
    );
  }

  testWidgets('a business gets its shop settings above the account actions', (tester) async {
    await tester.pumpWidget(buildTestable(
      const Profile(id: 'b', role: AccountRole.business, username: 'mle', referralCode: 'SHOPCODE'),
    ));
    await tester.pumpAndSettle();

    for (final item in ['Your shop', 'Shop page', 'Business details', 'Services', 'Subscription & billing', 'SHOPCODE']) {
      expect(find.text(item), findsOneWidget, reason: item);
    }
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
  });

  testWidgets('a customer manages their profile and account in the same place', (tester) async {
    await tester.pumpWidget(buildTestable(
      const Profile(id: 'c', role: AccountRole.customer, username: 'alex', referralCode: 'CODE'),
    ));
    await tester.pumpAndSettle();

    for (final item in ['Your profile', 'Profile photo', 'Worker profile', 'CODE', 'Sign out', 'Delete account']) {
      expect(find.text(item), findsOneWidget, reason: item);
    }
    expect(find.text('Your shop'), findsNothing);
  });

  testWidgets('an under-18 customer is not offered a worker profile', (tester) async {
    await tester.pumpWidget(buildTestable(
      const Profile(id: 'm', role: AccountRole.customer, username: 'sam', referralCode: 'CODE', isMinor: true),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Profile photo'), findsOneWidget);
    expect(find.text('Worker profile'), findsNothing);
  });
}
