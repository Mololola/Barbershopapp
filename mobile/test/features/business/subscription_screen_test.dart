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
  Future<void> cancelFinancePremium(String businessId) async => calls.add('cancel premium');

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

  Widget buildTestable(
    BusinessSubscription Function() current,
    _FakeBillingApi api, {
    FinancePremiumSubscription? Function()? premium,
  }) {
    return ProviderScope(
      overrides: [
        businessSubscriptionProvider.overrideWith((ref) async => current()),
        financePremiumSubscriptionProvider.overrideWith((ref) async => premium?.call()),
        currentBusinessProvider.overrideWith(
          (ref) async => const Business(id: 'b1', ownerId: 'o1', name: 'Shop', currency: 'GBP'),
        ),
        billingApiClientProvider.overrideWithValue(api),
      ],
      child: const MaterialApp(home: SubscriptionScreen()),
    );
  }

  testWidgets('during the trial, cancelling asks first and then shows when it ends', (tester) async {
    final api = _FakeBillingApi();
    var current = subscription();
    await tester.pumpWidget(buildTestable(() => current, api));
    await tester.pumpAndSettle();

    final date = formatSubscriptionDate(trialEnd);
    expect(find.text('£150 / month'), findsOneWidget);
    expect(find.text('Free trial'), findsOneWidget);
    expect(find.text('Free trial until $date'), findsOneWidget);

    await tester.tap(find.text('Cancel subscription'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your free trial still runs until $date and won\'t be charged again'), findsOneWidget);

    // The backend schedules the cancellation for the trial's end.
    current = subscription(cancelAt: trialEnd);
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel subscription'));
    await tester.pumpAndSettle();

    expect(api.calls, ['cancel']);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Ends $date'), findsOneWidget);
    expect(find.text('Subscription cancelled'), findsOneWidget);
    expect(find.text('Subscribe again'), findsOneWidget);
  });

  testWidgets('backing out of the dialog cancels nothing', (tester) async {
    final api = _FakeBillingApi();
    await tester.pumpWidget(buildTestable(subscription, api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel subscription'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();

    expect(api.calls, isEmpty);
    expect(find.text('Cancel subscription'), findsOneWidget);
  });

  testWidgets('a cancelled subscription restarts after confirming, and says so', (tester) async {
    final api = _FakeBillingApi();
    var current = subscription(cancelAt: trialEnd);
    await tester.pumpWidget(buildTestable(() => current, api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Subscribe again'));
    await tester.pumpAndSettle();
    expect(find.textContaining('your subscription (£150 / month) is charged to the card you already added'), findsOneWidget);

    current = subscription();
    await tester.tap(find.widgetWithText(FilledButton, 'Subscribe'));
    await tester.pumpAndSettle();

    expect(api.calls, ['resume']);
    expect(find.text('You\'re subscribed again'), findsOneWidget);
    expect(find.text('Free trial'), findsOneWidget);
    expect(find.text('Cancel subscription'), findsOneWidget);
  });

  testWidgets('Finance Premium has its own card and can be cancelled on its own', (tester) async {
    final api = _FakeBillingApi();
    var premium = const FinancePremiumSubscription(monthlyAmountCents: 999);
    await tester.pumpWidget(buildTestable(subscription, api, premium: () => premium));
    await tester.pumpAndSettle();

    expect(find.text('Finance Premium'), findsOneWidget);
    expect(find.text('£9.99 / month'), findsOneWidget);

    await tester.tap(find.text('Cancel subscription').last);
    await tester.pumpAndSettle();
    expect(find.text('Cancel Finance Premium?'), findsOneWidget);

    final premiumEnd = DateTime.now().toUtc().add(const Duration(days: 20));
    premium = FinancePremiumSubscription(monthlyAmountCents: 999, cancelAt: premiumEnd);
    await tester.tap(find.text('Cancel Premium'));
    await tester.pumpAndSettle();

    expect(api.calls, ['cancel premium']);
    expect(find.text('Ends ${formatSubscriptionDate(premiumEnd)}'), findsOneWidget);
    // The shop's own subscription is untouched.
    expect(find.text('Free trial'), findsOneWidget);
  });
}
