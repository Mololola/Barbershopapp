import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n.dart';
import '../../../core/loading.dart';
import '../../../core/theme.dart';
import '../application/business_controller.dart';
import '../domain/business.dart' show currencySymbol;
import '../domain/business_subscription.dart';
import '../domain/finance_overview.dart';
import 'subscription_banner.dart';

/// "Oct 26, 2026" / "26 oct 2026", in the phone's time zone.
String formatSubscriptionDate(AppLocalizations l10n, DateTime date) =>
    DateFormat.yMMMd(l10n.localeName).format(date.toLocal());

/// Settings › Subscription & billing: the shop's plan and the Finance
/// Premium add-on, each with a cancel button that's easy to find —
/// cancelling (always at the end of the trial or paid month) is done here;
/// card and invoices live in Stripe's portal.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action, String doneMessage) async {
    await action();
    if (!context.mounted) return;
    final state = ref.read(billingActionControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(state.hasError ? describeError(context.l10n, state.error) : doneMessage)),
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    required String backOutLabel,
    bool destructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(backOutLabel)),
          FilledButton(
            style: destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error) : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed == true && context.mounted;
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref, BusinessSubscription sub) async {
    // A trial isn't cancelled on its own: cancelling ends the subscription
    // when the trial (or paid month) runs out, and the shop is hidden until
    // the owner subscribes again.
    final l10n = context.l10n;
    final confirmed = await _confirm(
      context,
      title: l10n.cancelSubTitle,
      body: sub.isInTrial
          ? l10n.cancelSubBodyTrial(formatSubscriptionDate(l10n, sub.trialEndsAt!))
          : l10n.cancelSubBodyPaid,
      confirmLabel: l10n.cancelSubscription,
      backOutLabel: l10n.keepIt,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(billingActionControllerProvider.notifier).cancelSubscription(),
      l10n.subscriptionCancelled,
    );
  }

  Future<void> _confirmResubscribe(BuildContext context, WidgetRef ref, BusinessSubscription sub, String? price) async {
    // Undoes the scheduled cancellation on the same Stripe subscription, so
    // the card already on file is used — there's nothing to enter in Stripe.
    final l10n = context.l10n;
    final plan = price == null ? l10n.planNoPrice : l10n.planWithPrice(price);
    final confirmed = await _confirm(
      context,
      title: l10n.resubTitle,
      body: sub.isInTrial
          ? l10n.resubBodyTrial(formatSubscriptionDate(l10n, sub.trialEndsAt!), plan)
          : l10n.resubBodyPaid(plan),
      confirmLabel: l10n.subscribe,
      backOutLabel: l10n.notNow,
    );
    if (!confirmed || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(billingActionControllerProvider.notifier).resumeSubscription(),
      l10n.subscribedAgain,
    );
  }

  Future<void> _confirmCancelFinance(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await _confirm(
      context,
      title: l10n.cancelFinanceTitle,
      body: l10n.cancelFinanceBody,
      confirmLabel: l10n.cancelPremium,
      backOutLabel: l10n.keepIt,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(billingActionControllerProvider.notifier).cancelFinancePremium(),
      l10n.financeCancelled,
    );
  }

  Future<void> _confirmResubscribeFinance(BuildContext context, WidgetRef ref, String? price) async {
    final l10n = context.l10n;
    final confirmed = await _confirm(
      context,
      title: l10n.resubFinanceTitle,
      body: l10n.resubFinanceBody(price == null ? l10n.itPronoun : l10n.perMonth(price)),
      confirmLabel: l10n.subscribe,
      backOutLabel: l10n.notNow,
    );
    if (!confirmed || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(billingActionControllerProvider.notifier).resumeFinancePremium(),
      l10n.financeSubscribedAgain,
    );
  }

  Future<void> _openPortal(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final url = await ref.read(billingActionControllerProvider.notifier).openPortal();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, error))));
    }
  }

  Widget _cancelOrResubscribe(
    BuildContext context,
    bool busy,
    DateTime? cancelAt,
    VoidCallback cancel,
    VoidCallback resubscribe,
  ) {
    if (cancelAt != null) {
      return FilledButton(onPressed: busy ? null : resubscribe, child: Text(context.l10n.subscribeAgain));
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
      onPressed: busy ? null : cancel,
      child: Text(context.l10n.cancelSubscription),
    );
  }

  Widget _shopPlan(BuildContext context, WidgetRef ref, BusinessSubscription? sub, String? currency, bool busy) {
    if (sub != null && sub.grandfathered) {
      return Text(context.l10n.freeAccess);
    }
    if (sub == null || sub.status != SubscriptionStatus.active) {
      return const SubscriptionBanner();
    }
    final price = currency == null ? null : formatMoney(sub.monthlyAmountCents, currency);
    final action = _cancelOrResubscribe(
      context,
      busy,
      sub.cancelAt,
      () => _confirmCancel(context, ref, sub),
      () => _confirmResubscribe(context, ref, sub, price),
    );
    final l10n = context.l10n;
    if (sub.cancelAt != null) {
      return _PlanCard(
        name: l10n.shopSubscription,
        badge: l10n.badgeCancelled,
        cancelled: true,
        price: price,
        title: l10n.endsOn(formatSubscriptionDate(l10n, sub.cancelAt!)),
        message: l10n.shopCancelledMessage,
        action: action,
      );
    }
    if (sub.isInTrial) {
      return _PlanCard(
        name: l10n.shopSubscription,
        badge: l10n.badgeFreeTrial,
        price: price,
        title: l10n.freeTrialUntil(formatSubscriptionDate(l10n, sub.trialEndsAt!)),
        message: l10n.trialMessage,
        action: action,
      );
    }
    final symbol = currencySymbol(currency ?? 'GBP');
    return _PlanCard(
      name: l10n.shopSubscription,
      badge: l10n.badgeActive,
      price: price,
      title: l10n.renewsMonthly,
      message: sub.monthlyAmountCents > 10000
          ? '${l10n.shopActiveMessage} ${l10n.shopLoyaltyNote(symbol)}'
          : l10n.shopActiveMessage,
      action: action,
    );
  }

  Widget _financePlan(
    BuildContext context,
    WidgetRef ref,
    FinancePremiumSubscription premium,
    String? currency,
    bool busy,
  ) {
    final price = currency == null ? null : formatMoney(premium.monthlyAmountCents, currency);
    final cancelAt = premium.cancelAt;
    final l10n = context.l10n;
    return _PlanCard(
      name: 'Finance Premium',
      badge: cancelAt != null ? l10n.badgeCancelled : l10n.badgeActive,
      cancelled: cancelAt != null,
      price: price,
      title: cancelAt != null ? l10n.endsOn(formatSubscriptionDate(l10n, cancelAt)) : l10n.renewsMonthly,
      message: cancelAt != null
          ? l10n.financeCancelledMessage
          : l10n.financeActiveMessage(currencySymbol(currency ?? 'GBP')),
      action: _cancelOrResubscribe(
        context,
        busy,
        cancelAt,
        () => _confirmCancelFinance(context, ref),
        () => _confirmResubscribeFinance(context, ref, price),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(businessSubscriptionProvider);
    final premium = ref.watch(financePremiumSubscriptionProvider).value;
    final currency = ref.watch(currentBusinessProvider).value?.currency;
    final busy = ref.watch(billingActionControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.navSubscription)),
      body: subscription.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text(describeError(context.l10n, error))),
        data: (sub) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _shopPlan(context, ref, sub, currency, busy),
            if (premium != null) ...[
              const SizedBox(height: 12),
              _financePlan(context, ref, premium, currency, busy),
            ],
            if ((sub?.status == SubscriptionStatus.active && sub?.grandfathered == false) || premium != null) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.credit_card),
                title: Text(context.l10n.paymentMethodInvoices),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openPortal(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.name,
    required this.badge,
    this.cancelled = false,
    required this.price,
    required this.title,
    required this.message,
    required this.action,
  });

  final String name;
  final String badge;
  final bool cancelled;
  final String? price;
  final String title;
  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(name, style: textTheme.titleSmall),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cancelled ? AppColors.rust : AppColors.brass,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: textTheme.labelMedium?.copyWith(
                      color: cancelled ? AppColors.onRust : AppColors.onBrass,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (price != null) Text(context.l10n.perMonth(price!), style: textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    );
  }
}
