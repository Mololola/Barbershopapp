import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/application/admin_controller.dart';
import 'package:mobile/features/admin/domain/reviewer.dart';
import 'package:mobile/features/admin/presentation/admin_screen.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:mobile/features/customer/domain/review.dart';

void main() {
  const janeStandard = Profile(
    id: 'cust-1',
    role: AccountRole.customer,
    username: 'janedoe',
    referralCode: 'CODE1234',
  );
  const review = Review(
    bookingId: 'b1',
    businessId: 'biz-1',
    workerId: 'w1',
    customerId: 'cust-1',
    shopRating: 5,
    shopComment: 'Great shop, very clean.',
  );

  final reviewers = Reviewers(
    suggested: [
      Reviewer(
        id: 'cust-2',
        username: 'regular_rob',
        reviews: 7,
        averageCommentLength: 140,
        lastReviewAt: DateTime.utc(2026, 9, 20),
        memberSince: DateTime.utc(2026, 5, 1),
      ),
    ],
    promoted: [
      Reviewer(
        id: 'cust-3',
        username: 'top_tina',
        reviews: 12,
        averageCommentLength: 210,
        lastReviewAt: DateTime.utc(2026, 9, 25),
        memberSince: DateTime.utc(2026, 3, 1),
      ),
    ],
  );

  Widget buildTestable({required bool setSucceeds}) {
    return ProviderScope(
      overrides: [
        customerSearchProvider.overrideWith((ref, query) async => [janeStandard]),
        customerReviewsProvider.overrideWith((ref, customerId) async => [review]),
        // TabBarView builds every tab eagerly, not just the visible one, so
        // the Businesses/Payouts tabs' providers need overriding here too —
        // otherwise they'd hit a real (un-overridden) Supabase call and
        // pumpAndSettle would hang forever waiting on it.
        adminBusinessesProvider.overrideWith((ref) async => []),
        adminPayoutRequestsProvider.overrideWith((ref) async => []),
        // Overview is the first tab; these tests are about Customers.
        adminMetricsProvider.overrideWith((ref) async => throw UnimplementedError()),
        adminReviewersProvider.overrideWith((ref) async => reviewers),
        if (setSucceeds) adminActionControllerProvider.overrideWith(_FakeSuccessAdminActionController.new),
      ],
      child: const MaterialApp(home: AdminScreen()),
    );
  }

  testWidgets('without a search, shows who to promote and who is promoted', (tester) async {
    await tester.pumpWidget(buildTestable(setSucceeds: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customers'));
    await tester.pumpAndSettle();

    expect(find.text('@regular_rob'), findsOneWidget);
    expect(find.textContaining('7 reviews · ~140 characters each'), findsOneWidget);
    expect(find.text('Promoted (1)'), findsOneWidget);

    await tester.tap(find.text('@top_tina'));
    await tester.pumpAndSettle();

    // Already promoted, so the action offered is demotion.
    expect(find.text('Deactivate higher rewards'), findsOneWidget);
  });

  testWidgets('search, select a customer, and view their review history', (tester) async {
    await tester.pumpWidget(buildTestable(setSucceeds: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customers'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'jane');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.text('janedoe'), findsOneWidget);

    await tester.tap(find.text('janedoe'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Great shop, very clean.'), findsOneWidget);
    expect(find.text('Activate higher rewards'), findsOneWidget);
  });

  testWidgets('toggling quality reviewer flips the button label on success', (tester) async {
    await tester.pumpWidget(buildTestable(setSucceeds: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customers'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'jane');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.tap(find.text('janedoe'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activate higher rewards'));
    await tester.pumpAndSettle();

    expect(find.text('Deactivate higher rewards'), findsOneWidget);
  });
}

class _FakeSuccessAdminActionController extends AdminActionController {
  @override
  Future<bool> setQualityReviewer(String customerId, bool value) async => true;
}
