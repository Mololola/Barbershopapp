import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/legal.dart';
import 'package:mobile/core/policy_update_notice.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Profile profile(DateTime acceptedAt) => Profile(
        id: 'me-1',
        role: AccountRole.customer,
        username: 'me',
        referralCode: 'MYCODE01',
        termsAcceptedAt: acceptedAt,
      );

  Widget buildTestable(Profile me) => ProviderScope(
        overrides: [currentProfileProvider.overrideWith((ref) async => me)],
        child: const MaterialApp(home: PolicyUpdateNotice(child: Text('home'))),
      );

  final before = policiesEffective.subtract(const Duration(days: 30));

  testWidgets('someone who accepted older policies is told once', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(buildTestable(profile(before)));
    await tester.pumpAndSettle();

    expect(find.text('We\'ve updated our Terms and Privacy Policy'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Next launch: already seen on this device.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(buildTestable(profile(before)));
    await tester.pumpAndSettle();
    expect(find.text('We\'ve updated our Terms and Privacy Policy'), findsNothing);
  });

  testWidgets('someone who signed up under the current policies is not told', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(buildTestable(profile(policiesEffective.add(const Duration(hours: 1)))));
    await tester.pumpAndSettle();

    expect(find.text('We\'ve updated our Terms and Privacy Policy'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });
}
