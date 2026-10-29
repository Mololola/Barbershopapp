import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n.dart';
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
        title: Text(context.l10n.bankAccountTitle),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: holder,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: context.l10n.accountHolderName),
                validator: (value) => (value ?? '').trim().length < 2 ? context.l10n.enterAccountName : null,
              ),
              TextFormField(
                controller: iban,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: context.l10n.iban,
                  helperText: context.l10n.ibanHelper,
                ),
                validator: (value) => (value ?? '').trim().isEmpty ? context.l10n.enterYourIban : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;

    final error = await ref
        .read(payoutControllerProvider.notifier)
        .savePayoutDetails(accountHolder: holder.text.trim(), iban: iban.text);
    if (!context.mounted) return false;
    _show(context, error ?? context.l10n.bankAccountSaved);
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
        title: Text(context.l10n.withdrawCurrency(currency)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: context.l10n.amount, prefixText: symbol),
                validator: (value) {
                  final cents = parseCents(value);
                  if (cents == null || cents <= 0) return context.l10n.enterValidAmount;
                  if (cents > availableCents) return context.l10n.moreThanBalance;
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Text(context.l10n.payoutTo(details!.accountHolder, details.maskedIban)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, parseCents(controller.text));
            },
            child: Text(context.l10n.request),
          ),
        ],
      ),
    );
    if (amountCents == null || !context.mounted) return;

    final error =
        await ref.read(payoutControllerProvider.notifier).requestPayout(amountCents: amountCents, currency: currency);
    if (!context.mounted) return;
    _show(context, error ?? context.l10n.withdrawalRequested);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(rewardHistoryProvider);
    final referrals = ref.watch(referralsRankingProvider);
    final myProfile = ref.watch(currentProfileProvider).value;
    final availableBalance = ref.watch(availableBalanceProvider);
    final myPayoutRequests = ref.watch(myPayoutRequestsProvider);
    final payoutDetails = ref.watch(payoutDetailsProvider);
    final payoutState = ref.watch(payoutControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.rewardHistory)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // What's left after withdrawals (pending ones included) — the
          // money already requested is listed under Withdrawals below.
          availableBalance.when(
            loading: () => const CircularProgressIndicator(),
            error: (error, _) => Text(context.l10n.errorWithDetail('$error')),
            data: (balances) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.balanceLabel(formatBalances(balances)), style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                for (final MapEntry(key: currency, value: cents) in balances.entries)
                  if (cents > 0)
                    Row(
                      children: [
                        Expanded(child: Text(context.l10n.amountAvailable(formatMoney(cents, currency)))),
                        FilledButton(
                          onPressed: payoutState.isLoading ? null : () => _requestPayout(context, ref, currency, cents),
                          child: Text(context.l10n.withdraw),
                        ),
                      ],
                    ),
              ],
            ),
          ),
          payoutDetails.when(
            loading: () => const SizedBox.shrink(),
            error: (error, _) => Text(context.l10n.errorWithDetail('$error')),
            data: (details) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_balance_outlined),
              title: Text(details == null ? context.l10n.noBankAccountYet : '${details.accountHolder}, ${details.maskedIban}'),
              subtitle: Text(context.l10n.withdrawalsSentHere),
              trailing: TextButton(
                onPressed: payoutState.isLoading ? null : () => _editBankDetails(context, ref, details),
                child: Text(details == null ? context.l10n.add : context.l10n.change),
              ),
            ),
          ),
          const SizedBox(height: 16),
          myPayoutRequests.when(
            loading: () => const SizedBox.shrink(),
            error: (error, _) => Text(context.l10n.errorWithDetail('$error')),
            data: (requests) {
              if (requests.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.withdrawals, style: Theme.of(context).textTheme.titleMedium),
                  for (final request in requests)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(formatMoney(request.amountCents, request.currency)),
                      subtitle: Text(_payoutStatusLabel(context, request.status)),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(context.l10n.referrals, style: Theme.of(context).textTheme.titleMedium),
          referrals.when(
            loading: () => const CircularProgressIndicator(),
            error: (error, _) => Text(context.l10n.errorWithDetail('$error')),
            data: (entries) {
              final matches = entries.where((e) => e.customerId == myProfile?.id);
              final count = matches.isEmpty ? 0 : matches.first.value;
              final earned = <String, int>{};
              for (final entry in (history.value ?? []).where((e) => e.isReferral)) {
                earned[entry.currency] = (earned[entry.currency] ?? 0) + entry.amountCents;
              }
              return Text(context.l10n.referralSummary(count, formatBalances(earned)));
            },
          ),
          const SizedBox(height: 24),
          Text(context.l10n.reviews, style: Theme.of(context).textTheme.titleMedium),
          history.when(
            loading: () => const LoadingView(),
            error: (error, _) => Text(context.l10n.errorWithDetail('$error')),
            data: (entries) {
              final reviewRewards = entries.where((e) => !e.isReferral);
              if (reviewRewards.isEmpty) {
                return Text(context.l10n.noRewardsYet);
              }
              return Column(
                children: [
                  for (final entry in reviewRewards)
                    ListTile(
                      title: Text('+${formatMoney(entry.amountCents, entry.currency)}'),
                      subtitle: Text(DateFormat.yMMMd(context.l10n.localeName).add_Hm().format(entry.createdAt.toLocal())),
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

String _payoutStatusLabel(BuildContext context, PayoutRequestStatus status) => switch (status) {
      PayoutRequestStatus.pending => context.l10n.payoutPending,
      PayoutRequestStatus.approved => context.l10n.payoutApproved,
      PayoutRequestStatus.rejected => context.l10n.payoutRejected,
      PayoutRequestStatus.paid => context.l10n.payoutPaid,
    };
