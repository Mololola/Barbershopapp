import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/business/application/business_controller.dart';
import 'package:mobile/features/business/domain/business.dart';
import 'package:mobile/features/business/domain/business_finance_access.dart';
import 'package:mobile/features/business/presentation/finance_access_section.dart';

void main() {
  final business = Business(
    id: 'biz-1',
    ownerId: 'owner-1',
    name: 'Test Shop',
    currency: 'GBP',
  );

  Widget buildTestable(BusinessFinanceAccess? access) {
    return ProviderScope(
      overrides: [
        financeAccessProvider.overrideWith((ref) async => access),
      ],
      child: MaterialApp(home: Scaffold(body: FinanceAccessSection(business: business))),
    );
  }

  testWidgets('offers a trial and a one-off unlock when never started', (tester) async {
    await tester.pumpWidget(buildTestable(null));
    await tester.pumpAndSettle();

    expect(find.text('Start free trial'), findsOneWidget);
    expect(find.text('Pay £45.00 to unlock'), findsOneWidget);
  });

  testWidgets('shows days remaining during an active trial', (tester) async {
    await tester.pumpWidget(buildTestable(
      BusinessFinanceAccess(
        grandfathered: false,
        amountCents: 4500,
        trialStartedAt: DateTime.now().toUtc(),
        trialEndsAt: DateTime.now().toUtc().add(const Duration(days: 10)),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Free trial — 9 days left.'), findsOneWidget);
    expect(find.text('Pay £45.00 to unlock permanently'), findsOneWidget);
  });

  testWidgets('prompts to pay once the trial has expired unpaid', (tester) async {
    await tester.pumpWidget(buildTestable(
      BusinessFinanceAccess(
        grandfathered: false,
        amountCents: 4500,
        trialStartedAt: DateTime.now().toUtc().subtract(const Duration(days: 40)),
        trialEndsAt: DateTime.now().toUtc().subtract(const Duration(days: 10)),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Your free trial has ended.'), findsOneWidget);
    expect(find.text('Pay £45.00 to unlock'), findsOneWidget);
  });

  testWidgets('shows unlocked with no action once paid', (tester) async {
    await tester.pumpWidget(buildTestable(
      BusinessFinanceAccess(grandfathered: false, amountCents: 4500, paidAt: DateTime.now().toUtc()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Finance tool unlocked.'), findsOneWidget);
    expect(find.text('Start free trial'), findsNothing);
  });

  testWidgets('shows unlocked with no action when grandfathered', (tester) async {
    await tester.pumpWidget(buildTestable(
      const BusinessFinanceAccess(grandfathered: true, amountCents: 0),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Finance tool unlocked.'), findsOneWidget);
  });
}
