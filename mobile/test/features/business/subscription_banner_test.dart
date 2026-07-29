import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/business/application/business_controller.dart';
import 'package:mobile/features/business/domain/business_subscription.dart';
import 'package:mobile/features/business/presentation/subscription_banner.dart';

void main() {
  Widget buildTestable(BusinessSubscription? subscription) {
    return ProviderScope(
      overrides: [
        businessSubscriptionProvider.overrideWith((ref) async => subscription),
      ],
      child: const MaterialApp(home: Scaffold(body: SubscriptionBanner())),
    );
  }

  testWidgets('renders nothing for an active subscription', (tester) async {
    await tester.pumpWidget(buildTestable(
      const BusinessSubscription(status: SubscriptionStatus.active, grandfathered: false, monthlyAmountCents: 10000),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(SubscriptionBanner), findsOneWidget);
    expect(find.text('Subscribe'), findsNothing);
    expect(find.textContaining('suspended'), findsNothing);
  });

  testWidgets('renders nothing for a grandfathered subscription', (tester) async {
    await tester.pumpWidget(buildTestable(
      const BusinessSubscription(status: SubscriptionStatus.incomplete, grandfathered: true, monthlyAmountCents: 0),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Subscribe'), findsNothing);
  });

  testWidgets('prompts to subscribe when no subscription row exists yet (brand new business)', (tester) async {
    await tester.pumpWidget(buildTestable(null));
    await tester.pumpAndSettle();

    expect(find.text('Subscribe to activate your business account.'), findsOneWidget);
    expect(find.text('Subscribe'), findsOneWidget);
  });

  testWidgets('prompts to subscribe when incomplete (never subscribed)', (tester) async {
    await tester.pumpWidget(buildTestable(
      const BusinessSubscription(status: SubscriptionStatus.incomplete, grandfathered: false, monthlyAmountCents: 10000),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Subscribe to activate your business account.'), findsOneWidget);
    expect(find.text('Subscribe'), findsOneWidget);
  });

  testWidgets('shows the grace-period warning with days remaining when suspended', (tester) async {
    await tester.pumpWidget(buildTestable(
      BusinessSubscription(
        status: SubscriptionStatus.suspended,
        grandfathered: false,
        monthlyAmountCents: 10000,
        suspendedAt: DateTime.now().toUtc().subtract(const Duration(days: 10)),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Account suspended — payment failed'), findsOneWidget);
    expect(find.text('50 days left before your account and its data are permanently deleted.'), findsOneWidget);
    expect(find.text('Manage billing'), findsOneWidget);
  });
}
