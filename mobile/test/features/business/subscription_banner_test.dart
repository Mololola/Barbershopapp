import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/business/application/business_controller.dart';
import 'package:mobile/features/business/domain/business.dart';
import 'package:mobile/features/business/domain/business_subscription.dart';
import 'package:mobile/features/business/presentation/pay_on_website.dart';
import 'package:mobile/features/business/presentation/subscription_banner.dart';
import 'package:mobile/features/business/presentation/subscription_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

final en = lookupAppLocalizations(const Locale('en'));

void main() {
  // These tests cover the business website, where shops pay.
  setUp(() => canPayInThisApp = true);
  tearDown(() => canPayInThisApp = false);

  Widget buildTestable(BusinessSubscription? subscription, {DateTime? businessCreatedAt}) {
    return ProviderScope(
      overrides: [
        businessSubscriptionProvider.overrideWith((ref) async => subscription),
        currentBusinessProvider.overrideWith(
          (ref) async => Business(id: 'b1', ownerId: 'o1', name: 'Shop', currency: 'GBP', createdAt: businessCreatedAt),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: SubscriptionBanner())),
    );
  }

  testWidgets('the phone app shows where to pay instead of a Subscribe button', (tester) async {
    canPayInThisApp = false;
    await tester.pumpWidget(buildTestable(null));
    await tester.pumpAndSettle();

    expect(find.text('Subscribe'), findsNothing);
    expect(find.byType(PayOnWebsiteNote), findsOneWidget);
  });

  testWidgets('renders nothing for an active subscription', (tester) async {
    await tester.pumpWidget(buildTestable(
      const BusinessSubscription(status: SubscriptionStatus.active, grandfathered: false, monthlyAmountCents: 10000),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(SubscriptionBanner), findsOneWidget);
    expect(find.text('Subscribe'), findsNothing);
    expect(find.textContaining('deleted'), findsNothing);
  });

  testWidgets('during a free trial, says when it ends and that cancelling before then costs nothing', (tester) async {
    final trialEnd = DateTime.now().toUtc().add(const Duration(days: 5));
    await tester.pumpWidget(buildTestable(
      BusinessSubscription(
        status: SubscriptionStatus.active,
        grandfathered: false,
        monthlyAmountCents: 10000,
        trialEndsAt: trialEnd,
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.text('Free trial until ${formatSubscriptionDate(en, trialEnd)}. '
          'Cancel any time before then and you won\'t be charged.'),
      findsOneWidget,
    );
    expect(find.text('Manage'), findsOneWidget);
  });

  testWidgets('renders nothing for a grandfathered subscription', (tester) async {
    await tester.pumpWidget(buildTestable(
      const BusinessSubscription(status: SubscriptionStatus.incomplete, grandfathered: true, monthlyAmountCents: 0),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Subscribe'), findsNothing);
  });

  testWidgets('prompts to subscribe when no subscription row exists yet (brand new business)', (tester) async {
    await tester.pumpWidget(buildTestable(
      null,
      businessCreatedAt: DateTime.now().toUtc().subtract(const Duration(days: 20, hours: 1)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Your shop is hidden from customers until you subscribe.'), findsOneWidget);
    expect(find.text('40 days left before your shop and all its data are permanently deleted.'), findsOneWidget);
    expect(find.text('Subscribe'), findsOneWidget);
  });

  testWidgets('prompts to subscribe when incomplete (never subscribed)', (tester) async {
    await tester.pumpWidget(buildTestable(
      const BusinessSubscription(status: SubscriptionStatus.incomplete, grandfathered: false, monthlyAmountCents: 10000),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Your shop is hidden from customers until you subscribe.'), findsOneWidget);
    expect(find.text('Subscribe'), findsOneWidget);
  });

  testWidgets('a failed payment keeps the shop visible for 3 days, then counts down to deletion', (tester) async {
    await tester.pumpWidget(buildTestable(
      BusinessSubscription(
        status: SubscriptionStatus.suspended,
        grandfathered: false,
        monthlyAmountCents: 10000,
        suspendedAt: DateTime.now().toUtc().subtract(const Duration(days: 1, hours: 1)),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Payment failed'), findsOneWidget);
    expect(
      find.text('Customers can still find your shop for 2 days. '
          '59 days left before your shop and all its data are permanently deleted.'),
      findsOneWidget,
    );
    expect(find.text('Update payment'), findsOneWidget);
  });

  testWidgets('a canceled subscription past the 3 days is hidden and offers a new subscription', (tester) async {
    await tester.pumpWidget(buildTestable(
      BusinessSubscription(
        status: SubscriptionStatus.canceled,
        grandfathered: false,
        monthlyAmountCents: 10000,
        suspendedAt: DateTime.now().toUtc().subtract(const Duration(days: 13, hours: 1)),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Subscription ended'), findsOneWidget);
    expect(
      find.text('Your shop is hidden from customers. '
          '47 days left before your shop and all its data are permanently deleted.'),
      findsOneWidget,
    );
    expect(find.text('Subscribe'), findsOneWidget);
  });
}
