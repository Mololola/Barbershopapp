import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/application/admin_controller.dart';
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

  Widget buildTestable({required bool setSucceeds}) {
    return ProviderScope(
      overrides: [
        customerSearchProvider.overrideWith((ref, query) async => [janeStandard]),
        customerReviewsProvider.overrideWith((ref, customerId) async => [review]),
        if (setSucceeds) adminActionControllerProvider.overrideWith(_FakeSuccessAdminActionController.new),
      ],
      child: const MaterialApp(home: AdminScreen()),
    );
  }

  testWidgets('search, select a customer, and view their review history', (tester) async {
    await tester.pumpWidget(buildTestable(setSucceeds: true));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'jane');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.text('janedoe'), findsOneWidget);

    await tester.tap(find.text('janedoe'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Great shop, very clean.'), findsOneWidget);
    expect(find.text('Activate \$3 rewards'), findsOneWidget);
  });

  testWidgets('toggling quality reviewer flips the button label on success', (tester) async {
    await tester.pumpWidget(buildTestable(setSucceeds: true));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'jane');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.tap(find.text('janedoe'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activate \$3 rewards'));
    await tester.pumpAndSettle();

    expect(find.text('Deactivate \$3 rewards'), findsOneWidget);
  });
}

class _FakeSuccessAdminActionController extends AdminActionController {
  @override
  Future<bool> setQualityReviewer(String customerId, bool value) async => true;
}
