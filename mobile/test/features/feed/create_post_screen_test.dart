import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/feed/presentation/create_post_screen.dart';

void main() {
  Widget buildTestable() {
    return const ProviderScope(
      child: MaterialApp(home: CreatePostScreen()),
    );
  }

  FilledButton postButton(WidgetTester tester) => tester.widget<FilledButton>(find.byType(FilledButton));

  testWidgets('Post is disabled with no text and no image, enabled once text is entered', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(postButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Fresh fade today');
    await tester.pump();

    expect(postButton(tester).onPressed, isNotNull);
  });
}
