import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/supabase_providers.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:mobile/features/auth/presentation/sign_up_screen.dart';

void main() {
  testWidgets('shows validation errors when submitted empty', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentAuthUserIdProvider.overrideWithValue(null)],
        child: const MaterialApp(home: SignUpScreen()),
      ),
    );
    await tester.pump(); // let AuthController.build() resolve past its initial loading state

    await tester.tap(find.text('Sign up'));
    await tester.pump();

    expect(find.text('Required'), findsWidgets);
  });

  testWidgets('has a customer/business role selector defaulting to customer', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentAuthUserIdProvider.overrideWithValue(null)],
        child: const MaterialApp(home: SignUpScreen()),
      ),
    );

    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Business'), findsOneWidget);

    final segmented = tester.widget<SegmentedButton<AccountRole>>(
      find.byType(SegmentedButton<AccountRole>),
    );
    expect(segmented.selected, {AccountRole.customer});
  });

  testWidgets('business mode: asks for a business name and owner attestation instead of date of birth',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentAuthUserIdProvider.overrideWithValue(null)],
        child: const MaterialApp(home: SignUpScreen()),
      ),
    );

    expect(find.text('Date of birth'), findsOneWidget);

    await tester.tap(find.text('Business'));
    await tester.pump();

    expect(find.text('Create business account'), findsOneWidget);
    expect(find.text('Date of birth'), findsNothing);
    expect(find.text('Business name'), findsOneWidget);
    expect(find.text('Business handle'), findsOneWidget);
    expect(find.text("I'm 18 or over and authorised to register this business"), findsOneWidget);
  });

  testWidgets('OAuth completion: hides email/password and shows Finish', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentAuthUserIdProvider.overrideWithValue('oauth-user-id')],
        child: const MaterialApp(home: SignUpScreen()),
      ),
    );
    await tester.pump(); // let AuthController.build() resolve past its initial loading state

    expect(find.text('Email'), findsNothing);
    expect(find.text('Password'), findsNothing);
    expect(find.text('Finish'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
  });
}
