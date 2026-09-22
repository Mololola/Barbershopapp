import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/loading.dart';
import '../../auth/application/auth_controller.dart';
import '../../rankings/application/rankings_controller.dart';
import '../application/rewards_controller.dart';
import '../domain/payout_request.dart';

class RewardHistoryScreen extends ConsumerWidget {
  const RewardHistoryScreen({super.key});

  Future<void> _requestPayout(BuildContext context, WidgetRef ref, int availableCents) async {
    final controller = TextEditingController(text: (availableCents / 100).toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();

    final amountCents = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request payout'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount (\$)', prefixText: '\$'),
            validator: (value) {
              final parsed = double.tryParse(value ?? '');
              if (parsed == null || parsed <= 0) return 'Enter a valid amount';
              if ((parsed * 100).round() > availableCents) return 'More than your available balance';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, (double.parse(controller.text) * 100).round());
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
    if (amountCents == null || !context.mounted) return;

    final success = await ref.read(payoutControllerProvider.notifier).requestPayout(amountCents);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'Payout requested.' : 'Could not request payout — try again.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(rewardBalanceProvider);
    final history = ref.watch(rewardHistoryProvider);
    final referrals = ref.watch(referralsRankingProvider);
    final myProfile = ref.watch(currentProfileProvider).value;
    final availableBalance = ref.watch(availableBalanceProvider);
    final myPayoutRequests = ref.watch(myPayoutRequestsProvider);
    final payoutState = ref.watch(payoutControllerProvider);

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
          const SizedBox(height: 8),
          availableBalance.when(
            loading: () => const SizedBox.shrink(),
            error: (error, _) => Text('Error: $error'),
            data: (cents) => Row(
              children: [
                Expanded(child: Text('Available to withdraw: \$${(cents / 100).toStringAsFixed(2)}')),
                FilledButton(
                  onPressed: (cents <= 0 || payoutState.isLoading) ? null : () => _requestPayout(context, ref, cents),
                  child: const Text('Request payout'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          myPayoutRequests.when(
            loading: () => const SizedBox.shrink(),
            error: (error, _) => Text('Error: $error'),
            data: (requests) {
              if (requests.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payout requests', style: Theme.of(context).textTheme.titleMedium),
                  for (final request in requests)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('\$${(request.amountCents / 100).toStringAsFixed(2)}'),
                      subtitle: Text(_payoutStatusLabel(request.status)),
                    ),
                ],
              );
            },
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
            loading: () => const LoadingView(),
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

String _payoutStatusLabel(PayoutRequestStatus status) {
  return switch (status) {
    PayoutRequestStatus.pending => 'Pending review',
    PayoutRequestStatus.approved => 'Approved — payment on its way',
    PayoutRequestStatus.rejected => 'Rejected',
    PayoutRequestStatus.paid => 'Paid',
  };
}
