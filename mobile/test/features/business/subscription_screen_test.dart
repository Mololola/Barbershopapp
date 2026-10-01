import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/business/application/business_controller.dart';
import 'package:mobile/features/business/data/billing_api_client.dart';
import 'package:mobile/features/business/domain/business.dart';
import 'package:mobile/features/business/domain/business_subscription.dart';
import 'package:mobile/features/business/presentation/subscription_screen.dart';

class _FakeBillingApi implements BillingApiClient {
  final calls = <String>[];

  @override
  Future<void> cancelSubscription(String businessId) async => calls.add('cancel');

  @override
  Future<void> resumeSubscription(String businessId) async => calls.add('resume');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final trialEnd = DateTime.now().toUtc().add(const Duration(days: 10));

  BusinessSubscription subscription({DateTime? cancelAt}) => BusinessSubscription(
        status: SubscriptionStatus.active,
        grandfathered: false,
        monthlyAmountCents: 15000,
        trialEndsAt: trialEnd,
        cancelAt: cancelAt,
      );

  Widget buildTestable(BusinessSubscription Function() current, _FakeBillingApi api) {
    return ProviderScope(
      overrides: [
        businessSubscriptionProvider.overrideWith((ref) async => current()),
        currentBusinessProvider.overrideWith(
          (ref) async => const Business(id: 'b1', ownerId: 'o1', name: 'Shop', currency: 'GBP'),
        ),
        billingApiClientProvider.overrideWithValue(api),
      ],
      child: const MaterialApp(home: SubscriptionScreen()),
    );
  }

  testWidgets('during the trial, cancelling asks first and then shows access until the trial ends', (tester) async {
    final api = _FakeBillingApi();
    var current = subscription();
    await tester.pumpWidget(buildTestable(() => current, api));
    await tester.pumpAndSettle();

    final date = formatSubscriptionDate(trialEnd);
    expect(find.text('£150 / month'), findsOneWidget);
    expect(find.text('Free trial until $date'), findsOneWidget);

    await tester.tap(find.text('Cancel free trial'));
    await tester.pumpAndSettle();
    expect(find.textContaining('You keep full access until $date and won\'t be charged anything'), findsOneWidget);

    // The backend schedules the cancellation for the trial's end.
    current = subscription(cancelAt: trialEnd);
    await tester.tap(find.text('Cancel trial'));
    await tester.pumpAndSettle();

    expect(api.calls, ['cancel']);
    expect(find.text('Free trial cancelled'), findsOneWidget);
    expect(find.textContaining('You keep full access until $date and won\'t be charged.'), findsOneWidget);
    expect(find.text('Keep my subscription'), findsOneWidget);
  });

  testWidgets('backing out of the dialog cancels nothing', (tester) async {
    final api = _FakeBillingApi();
    await tester.pumpWidget(buildTestable(subscription, api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel free trial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();

    expect(api.calls, isEmpty);
    expect(find.text('Cancel free trial'), findsOneWidget);
  });

  testWidgets('a cancelled trial can be undone', (tester) async {
    final api = _FakeBillingApi();
    var current = subscription(cancelAt: trialEnd);
    await tester.pumpWidget(buildTestable(() => current, api));
    await tester.pumpAndSettle();

    current = subscription();
    await tester.tap(find.text('Keep my subscription'));
    await tester.pumpAndSettle();

    expect(api.calls, ['resume']);
    expect(find.text('Cancel free trial'), findsOneWidget);
  });
}
