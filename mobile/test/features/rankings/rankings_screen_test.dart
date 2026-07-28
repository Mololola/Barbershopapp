import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/rankings/application/rankings_controller.dart';
import 'package:mobile/features/rankings/domain/ranking_entry.dart';
import 'package:mobile/features/rankings/presentation/rankings_screen.dart';

void main() {
  const shopEntry = CustomerRankingEntry(customerId: 'c1', username: 'alex', avatarUrl: null, value: 5);
  const referralEntry = CustomerRankingEntry(customerId: 'c2', username: 'sam', avatarUrl: null, value: 2);
  const haircutEntry = HaircutTypeRankingEntry(haircutType: 'Fade', value: 12);

  Widget buildTestable() {
    return ProviderScope(
      overrides: [
        distinctShopsRankingProvider.overrideWith((ref, window) async => [shopEntry]),
        totalHaircutsRankingProvider.overrideWith((ref, window) async => [shopEntry]),
        haircutTypesRankingProvider.overrideWith((ref, window) async => [haircutEntry]),
        referralsRankingProvider.overrideWith((ref) async => [referralEntry]),
      ],
      child: const MaterialApp(home: RankingsScreen()),
    );
  }

  testWidgets('shows entries and a window selector for the default ranking', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('alex'), findsOneWidget);
    expect(find.text('5 shops'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
  });

  testWidgets('switching to "Top referrers" hides the window selector', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Most shops visited'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top referrers').last);
    await tester.pumpAndSettle();

    expect(find.text('This week'), findsNothing);
    expect(find.text('sam'), findsOneWidget);
    expect(find.text('2 businesses referred'), findsOneWidget);
  });

  testWidgets('"Popular haircuts" shows haircut types, not usernames', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Most shops visited'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Popular haircuts').last);
    await tester.pumpAndSettle();

    expect(find.text('Fade'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });
}
