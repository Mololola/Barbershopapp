import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:mobile/features/rankings/application/rankings_controller.dart';
import 'package:mobile/features/rankings/domain/ranking_entry.dart';
import 'package:mobile/features/rankings/presentation/rankings_screen.dart';

void main() {
  const shopEntry = CustomerRankingEntry(customerId: 'c1', username: 'alex', avatarUrl: null, value: 5);
  const referralEntry = CustomerRankingEntry(customerId: 'c2', username: 'sam', avatarUrl: null, value: 2);
  const haircutEntry = HaircutTypeRankingEntry(haircutType: 'Fade', value: 12);

  Widget buildTestable({AccountRole? role}) {
    return ProviderScope(
      overrides: [
        distinctShopsRankingProvider.overrideWith((ref, window) async => [shopEntry]),
        totalHaircutsRankingProvider.overrideWith((ref, window) async => [shopEntry]),
        haircutTypesRankingProvider.overrideWith((ref, window) async => [haircutEntry]),
        referralsRankingProvider.overrideWith((ref) async => [referralEntry]),
        topBarbersRankingProvider.overrideWith((ref) async => []),
        currentProfileProvider.overrideWith(
          (ref) async => role == null ? null : Profile(id: 'me', role: role, username: 'me', referralCode: 'REF'),
        ),
      ],
      child: const MaterialApp(home: RankingsScreen()),
    );
  }

  // The ranking types scroll sideways; later ones start off-screen.
  Future<void> selectType(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(find.text(label), 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
  }

  testWidgets('shows entries and a window selector for the default ranking', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('alex'), findsOneWidget);
    expect(find.text('5 shops', findRichText: true), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
  });

  testWidgets('switching to "Top referrers" hides the window selector', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await selectType(tester, 'Top referrers');
    await tester.pumpAndSettle();

    expect(find.text('This week'), findsNothing);
    expect(find.text('sam'), findsOneWidget);
    expect(find.text('2 businesses referred', findRichText: true), findsOneWidget);
  });

  testWidgets('"Popular haircuts" shows haircut types, not usernames', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await selectType(tester, 'Popular haircuts');
    await tester.pumpAndSettle();

    expect(find.text('Fade'), findsOneWidget);
    expect(find.text('12 cuts', findRichText: true), findsOneWidget);
  });

  testWidgets('an empty board explains itself', (tester) async {
    await tester.pumpWidget(buildTestable(role: AccountRole.business));
    await tester.pumpAndSettle();

    await selectType(tester, 'Top-rated barbers');
    await tester.pumpAndSettle();

    expect(find.text('No rated barbers yet'), findsOneWidget);
  });

  testWidgets('customers are not offered the barber ranking', (tester) async {
    await tester.pumpWidget(buildTestable(role: AccountRole.customer));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).first, const Offset(-1000, 0));
    await tester.pumpAndSettle();

    expect(find.text('Top-rated barbers'), findsNothing);
    expect(find.text('Popular haircuts'), findsOneWidget);
  });
}
