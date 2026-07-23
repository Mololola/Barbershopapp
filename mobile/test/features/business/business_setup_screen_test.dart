import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/business/presentation/business_setup_screen.dart';

void main() {
  testWidgets('shows validation errors when submitted empty', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: BusinessSetupScreen())),
    );
    await tester.pumpAndSettle(); // let BusinessSetupController.build() resolve

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

  testWidgets('starts with one location row and can add another', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: BusinessSetupScreen())),
    );

    expect(find.text('Address'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);

    await tester.tap(find.text('Add another location'));
    await tester.pump();

    expect(find.text('Address'), findsNWidgets(2));
    expect(find.text('City'), findsNWidgets(2));
  });
}
