import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../rankings/application/rankings_controller.dart';
import '../application/rewards_controller.dart';

class RewardHistoryScreen extends ConsumerWidget {
  const RewardHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(rewardBalanceProvider);
    final history = ref.watch(rewardHistoryProvider);
    final referrals = ref.watch(referralsRankingProvider);
    final myProfile = ref.watch(currentProfileProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Reward history')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          balance.when(
            loading: () => const CircularProgressIndicator(),
            error: (error, _) => Text('Error: $error'),
            data: (cents) => Text(
              'Balance: \$${(cents / 100).toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 24),
          Text('Referrals', style: Theme.of(context).textTheme.titleMedium),
          referrals.when(
            loading: () => const CircularProgressIndicator(),
            error: (error, _) => Text('Error: $error'),
            data: (entries) {
              final matches = entries.where((e) => e.customerId == myProfile?.id);
              final count = matches.isEmpty ? 0 : matches.first.value;
              return Text(
                '$count business${count == 1 ? '' : 'es'} referred — \$0.00 '
                '(arrives with Stripe billing)',
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Reviews', style: Theme.of(context).textTheme.titleMedium),
          history.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Error: $error'),
            data: (entries) {
              if (entries.isEmpty) {
                return const Text('No rewards yet.');
              }
              return Column(
                children: [
                  for (final entry in entries)
                    ListTile(
                      title: Text('+\$${(entry.amountCents / 100).toStringAsFixed(2)}'),
                      subtitle: Text(entry.createdAt.toLocal().toString().split('.').first),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
