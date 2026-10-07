import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:mobile/features/rankings/application/rankings_controller.dart';
import 'package:mobile/features/rankings/domain/ranking_entry.dart';
import 'package:mobile/features/rewards/application/rewards_controller.dart';
import 'package:mobile/features/rewards/domain/reward_ledger_entry.dart';
import 'package:mobile/features/rewards/presentation/reward_history_screen.dart';

void main() {
  const myProfile = Profile(id: 'me-1', role: AccountRole.customer, username: 'me', referralCode: 'MYCODE01');
  final entry = RewardLedgerEntry(id: 'r1', amountCents: 200, createdAt: DateTime.utc(2026, 8, 1));
  final referralEarning =
      RewardLedgerEntry(id: 'r2', amountCents: 150, createdAt: DateTime.utc(2026, 8, 2), isReferral: true);
  const referral = CustomerRankingEntry(customerId: 'me-1', username: 'me', avatarUrl: null, value: 2);

  Widget buildTestable() {
    return ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) async => myProfile),
        rewardBalanceProvider.overrideWith((ref) async => 500),
        rewardHistoryProvider.overrideWith((ref) async => [entry, referralEarning]),
        referralsRankingProvider.overrideWith((ref) async => [referral]),
        myPayoutRequestsProvider.overrideWith((ref) async => []),
      ],
      child: const MaterialApp(home: RewardHistoryScreen()),
    );
  }

  testWidgets('shows the balance, referral count, and ledger history', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('Balance: \$5.00'), findsOneWidget);
    expect(find.textContaining('2 businesses referred — \$1.50 earned'), findsOneWidget);
    expect(find.text('+\$2.00'), findsOneWidget);
    expect(find.text('+\$1.50'), findsNothing);
  });
}
