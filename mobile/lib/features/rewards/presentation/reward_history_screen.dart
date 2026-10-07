import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/loading.dart';
import '../../auth/application/auth_controller.dart';
import '../../business/domain/business.dart';
import '../../business/domain/finance_overview.dart';
import '../../rankings/application/rankings_controller.dart';
import '../application/rewards_controller.dart';
import '../domain/payout_details.dart';
import '../domain/payout_request.dart';

class RewardHistoryScreen extends ConsumerWidget {
  const RewardHistoryScreen({super.key});

  void _show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Returns whether bank details were saved.
  Future<bool> _editBankDetails(BuildContext context, WidgetRef ref, PayoutDetails? current) async {
    final holder = TextEditingController(text: current?.accountHolder);
    final iban = TextEditingController(text: current?.iban);
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bank account for withdrawals'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: holder,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Account holder name'),
                validator: (value) => (value ?? '').trim().length < 2 ? 'Enter the name on the account' : null,
              ),
              TextFormField(
                controller: iban,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'IBAN',
                  helperText: 'In your banking app. UK accounts have one too (starts GB).',
                ),
                validator: (value) => (value ?? '').trim().isEmpty ? 'Enter your IBAN' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;

    final error = await ref
        .read(payoutControllerProvider.notifier)
        .savePayoutDetails(accountHolder: holder.text.trim(), iban: iban.text);
    if (!context.mounted) return false;
    _show(context, error ?? 'Bank account saved.');
    return error == null;
  }

  Future<void> _requestPayout(BuildContext context, WidgetRef ref, String currency, int availableCents) async {
    var details = await ref.read(payoutDetailsProvider.future);
    if (!context.mounted) return;
    if (details == null) {
      if (!await _editBankDetails(context, ref, null) || !context.mounted) return;
      details = await ref.read(payoutDetailsProvider.future);
      if (details == null || !context.mounted) return;
    }

    final symbol = currencySymbol(currency);
    final controller = TextEditingController(text: (availableCents / 100).toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();
    int? parseCents(String? value) {
      final parsed = double.tryParse((value ?? '').replaceAll(',', '.'));
      return parsed == null ? null : (parsed * 100).round();
    }

    final amountCents = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Withdraw $currency'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Amount', prefixText: symbol),
                validator: (value) {
                  final cents = parseCents(value);
                  if (cents == null || cents <= 0) return 'Enter a valid amount';
                  if (cents > availableCents) return 'More than your available balance';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Text('To ${details!.accountHolder}, ${details.maskedIban}'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, parseCents(controller.text));
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
    if (amountCents == null || !context.mounted) return;

    final error =
        await ref.read(payoutControllerProvider.notifier).requestPayout(amountCents: amountCents, currency: currency);
    if (!context.mounted) return;
    _show(context, error ?? 'Withdrawal requested.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(rewardBalanceProvider);
    final history = ref.watch(rewardHistoryProvider);
    final referrals = ref.watch(referralsRankingProvider);
    final myProfile = ref.watch(currentProfileProvider).value;
    final availableBalance = ref.watch(availableBalanceProvider);
    final myPayoutRequests = ref.watch(myPayoutRequestsProvider);
    final payoutDetails = ref.watch(payoutDetailsProvider);
    final payoutState = ref.watch(payoutControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reward history')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          balance.when(
            loading: () => const CircularProgressIndicator(),
            error: (error, _) => Text('Error: $error'),
            data: (balances) => Text(
              'Balance: ${formatBalances(balances)}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 8),
          availableBalance.when(
            loading: () => const SizedBox.shrink(),
            error: (error, _) => Text('Error: $error'),
            data: (balances) => Column(
              children: [
                for (final MapEntry(key: currency, value: cents) in balances.entries)
                  Row(
                    children: [
                      Expanded(child: Text('Available to withdraw: ${formatMoney(cents, currency)}')),
                      FilledButton(
                        onPressed: (cents <= 0 || payoutState.isLoading)
                            ? null
                            : () => _requestPayout(context, ref, currency, cents),
                        child: const Text('Withdraw'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          payoutDetails.when(
            loading: () => const SizedBox.shrink(),
            error: (error, _) => Text('Error: $error'),
            data: (details) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_balance_outlined),
              title: Text(details == null ? 'No bank account yet' : '${details.accountHolder}, ${details.maskedIban}'),
              subtitle: const Text('Withdrawals are sent here by bank transfer'),
              trailing: TextButton(
                onPressed: payoutState.isLoading ? null : () => _editBankDetails(context, ref, details),
                child: Text(details == null ? 'Add' : 'Change'),
              ),
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
                  Text('Withdrawals', style: Theme.of(context).textTheme.titleMedium),
                  for (final request in requests)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(formatMoney(request.amountCents, request.currency)),
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
              final earned = <String, int>{};
              for (final entry in (history.value ?? []).where((e) => e.isReferral)) {
                earned[entry.currency] = (earned[entry.currency] ?? 0) + entry.amountCents;
              }
              return Text(
                '$count business${count == 1 ? '' : 'es'} referred — '
                '${formatBalances(earned)} earned (5% of their subscription payments)',
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Reviews', style: Theme.of(context).textTheme.titleMedium),
          history.when(
            loading: () => const LoadingView(),
            error: (error, _) => Text('Error: $error'),
            data: (entries) {
              final reviewRewards = entries.where((e) => !e.isReferral);
              if (reviewRewards.isEmpty) {
                return const Text('No rewards yet.');
              }
              return Column(
                children: [
                  for (final entry in reviewRewards)
                    ListTile(
                      title: Text('+${formatMoney(entry.amountCents, entry.currency)}'),
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
