import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:mobile/features/auth/presentation/sign_up_screen.dart';

void main() {
  testWidgets('shows validation errors when submitted empty', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SignUpScreen())),
    );
    await tester.pump(); // let AuthController.build() resolve past its initial loading state

    await tester.tap(find.text('Sign up'));
    await tester.pump();

    expect(find.text('Required'), findsWidgets);
  });

  testWidgets('has a customer/business role selector defaulting to customer', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SignUpScreen())),
    );

    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Business'), findsOneWidget);

    final segmented = tester.widget<SegmentedButton<AccountRole>>(
      find.byType(SegmentedButton<AccountRole>),
    );
    expect(segmented.selected, {AccountRole.customer});
  });
}
