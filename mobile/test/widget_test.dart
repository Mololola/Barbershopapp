import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('SignInScreen renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SignInScreen())),
    );

    expect(find.text('Sign in'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
