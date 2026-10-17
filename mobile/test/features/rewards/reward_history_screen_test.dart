import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:mobile/features/rankings/application/rankings_controller.dart';
import 'package:mobile/features/rankings/domain/ranking_entry.dart';
import 'package:mobile/features/rewards/application/rewards_controller.dart';
import 'package:mobile/features/rewards/domain/payout_details.dart';
import 'package:mobile/features/rewards/domain/payout_request.dart';
import 'package:mobile/features/rewards/domain/reward_ledger_entry.dart';
import 'package:mobile/features/rewards/presentation/reward_history_screen.dart';

void main() {
  const myProfile = Profile(id: 'me-1', role: AccountRole.customer, username: 'me', referralCode: 'MYCODE01');
  final entry = RewardLedgerEntry(id: 'r1', amountCents: 200, currency: 'GBP', createdAt: DateTime.utc(2026, 8, 1));
  final referralEarning = RewardLedgerEntry(
    id: 'r2',
    amountCents: 1000,
    currency: 'EUR',
    createdAt: DateTime.utc(2026, 8, 2),
    isReferral: true,
  );
  // The whole €10 referral has already been withdrawn and paid.
  final paidWithdrawal = PayoutRequest(
    id: 'w1',
    profileId: 'me-1',
    amountCents: 1000,
    currency: 'EUR',
    status: PayoutRequestStatus.paid,
    requestedAt: DateTime.utc(2026, 8, 3),
  );
  const referral = CustomerRankingEntry(customerId: 'me-1', username: 'me', avatarUrl: null, value: 2);

  Widget buildTestable() {
    return ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => myProfile),
        rewardBalanceProvider.overrideWith((ref) async => {'GBP': 200, 'EUR': 1000}),
        rewardHistoryProvider.overrideWith((ref) async => [entry, referralEarning]),
        referralsRankingProvider.overrideWith((ref) async => [referral]),
        myPayoutRequestsProvider.overrideWith((ref) async => [paidWithdrawal]),
        payoutDetailsProvider.overrideWith(
          (ref) async => const PayoutDetails(accountHolder: 'Ana Ruiz', iban: 'ES9121000418450200051332'),
        ),
      ],
      child: const MaterialApp(home: RewardHistoryScreen()),
    );
  }

  testWidgets('balance is what is left after withdrawals; a fully withdrawn currency drops out', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('Balance: £2'), findsOneWidget);
    expect(find.text('£2 available'), findsOneWidget);
    expect(find.text('€10 available'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Withdraw'), findsOneWidget);
    expect(find.textContaining('2 businesses referred — €10 earned'), findsOneWidget);
    expect(find.text('Ana Ruiz, ES91 •••• 1332'), findsOneWidget);
    expect(find.text('+£2'), findsOneWidget);
    expect(find.text('+€10'), findsNothing);
  });
}
