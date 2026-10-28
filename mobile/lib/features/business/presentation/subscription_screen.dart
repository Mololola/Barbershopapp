import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/loading.dart';
import '../../../core/theme.dart';
import '../application/business_controller.dart';
import '../domain/business.dart' show currencySymbol;
import '../domain/business_subscription.dart';
import '../domain/finance_overview.dart';
import 'subscription_banner.dart';

const _monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "26 Oct 2026", in the phone's time zone.
String formatSubscriptionDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day} ${_monthShort[local.month - 1]} ${local.year}';
}

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
      SnackBar(content: Text(state.hasError ? state.error.toString() : doneMessage)),
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
    final until = sub.isInTrial
        ? 'Your free trial still runs until ${formatSubscriptionDate(sub.trialEndsAt!)}'
        : 'You keep full access until the end of the month you\'ve paid for';
    final confirmed = await _confirm(
      context,
      title: 'Cancel your subscription?',
      body: '$until and won\'t be charged again. After that your shop is hidden from customers until you '
          'subscribe again.',
      confirmLabel: 'Cancel subscription',
      backOutLabel: 'Keep it',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(billingActionControllerProvider.notifier).cancelSubscription(),
      'Subscription cancelled',
    );
  }

  Future<void> _confirmResubscribe(BuildContext context, WidgetRef ref, BusinessSubscription sub, String? price) async {
    // Undoes the scheduled cancellation on the same Stripe subscription, so
    // the card already on file is used — there's nothing to enter in Stripe.
    final plan = price == null ? 'your subscription' : 'your subscription ($price / month)';
    final confirmed = await _confirm(
      context,
      title: 'Subscribe again?',
      body: sub.isInTrial
          ? 'Your free trial continues until ${formatSubscriptionDate(sub.trialEndsAt!)}. After that, '
                '$plan is charged to the card you already added.'
          : 'We\'ll keep charging $plan to the card you already added. Nothing extra is charged today.',
      confirmLabel: 'Subscribe',
      backOutLabel: 'Not now',
    );
    if (!confirmed || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(billingActionControllerProvider.notifier).resumeSubscription(),
      'You\'re subscribed again',
    );
  }

  Future<void> _confirmCancelFinance(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: 'Cancel Finance Premium?',
      body: 'You keep Premium insights until the end of the month you\'ve paid for and won\'t be charged '
          'again. The free finance summary stays.',
      confirmLabel: 'Cancel Premium',
      backOutLabel: 'Keep it',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(billingActionControllerProvider.notifier).cancelFinancePremium(),
      'Finance Premium cancelled',
    );
  }

  Future<void> _confirmResubscribeFinance(BuildContext context, WidgetRef ref, String? price) async {
    final confirmed = await _confirm(
      context,
      title: 'Subscribe to Finance Premium again?',
      body: 'We\'ll keep charging ${price == null ? 'it' : '$price / month'} to the card you already added. '
          'Nothing extra is charged today.',
      confirmLabel: 'Subscribe',
      backOutLabel: 'Not now',
    );
    if (!confirmed || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(billingActionControllerProvider.notifier).resumeFinancePremium(),
      'You\'re subscribed to Finance Premium again',
    );
  }

  Future<void> _openPortal(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await ref.read(billingActionControllerProvider.notifier).openPortal();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
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
      return FilledButton(onPressed: busy ? null : resubscribe, child: const Text('Subscribe again'));
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
      onPressed: busy ? null : cancel,
      child: const Text('Cancel subscription'),
    );
  }

  Widget _shopPlan(BuildContext context, WidgetRef ref, BusinessSubscription? sub, String? currency, bool busy) {
    if (sub != null && sub.grandfathered) {
      return const Text('Your shop has free access — there\'s nothing to pay.');
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
    if (sub.cancelAt != null) {
      return _PlanCard(
        name: 'Shop subscription',
        badge: 'Cancelled',
        cancelled: true,
        price: price,
        title: 'Ends ${formatSubscriptionDate(sub.cancelAt!)}',
        message: 'Your shop stays visible to customers until then and you won\'t be charged again. After '
            'that it\'s hidden until you subscribe again, and its data is kept for 60 days.',
        action: action,
      );
    }
    if (sub.isInTrial) {
      return _PlanCard(
        name: 'Shop subscription',
        badge: 'Free trial',
        price: price,
        title: 'Free trial until ${formatSubscriptionDate(sub.trialEndsAt!)}',
        message: 'Nothing is charged before then. After that it renews every month — cancel any time '
            'before the trial ends and you pay nothing.',
        action: action,
      );
    }
    final symbol = currencySymbol(currency ?? 'GBP');
    return _PlanCard(
      name: 'Shop subscription',
      badge: 'Active',
      price: price,
      title: 'Renews every month',
      message: 'Cancel any time — you keep access until the end of the month you\'ve paid for.'
          '${sub.monthlyAmountCents > 10000 ? ' Every 2 months you stay, it costs ${symbol}5 less, never below '
              '${symbol}100 and at most ${symbol}100 off in all.' : ''}',
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
    return _PlanCard(
      name: 'Finance Premium',
      badge: cancelAt != null ? 'Cancelled' : 'Active',
      cancelled: cancelAt != null,
      price: price,
      title: cancelAt != null ? 'Ends ${formatSubscriptionDate(cancelAt)}' : 'Renews every month',
      message: cancelAt != null
          ? 'Premium insights stay on until then and you won\'t be charged again. The free finance summary '
                'stays after that.'
          : 'Cancel any time — you keep Premium insights until the end of the month you\'ve paid for. Every 2 '
                'months you stay, it costs ${currencySymbol(currency ?? 'GBP')}1 less, up to '
                '${currencySymbol(currency ?? 'GBP')}5 off.',
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
      appBar: AppBar(title: const Text('Subscription')),
      body: subscription.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text('Error: $error')),
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
                title: const Text('Payment method & invoices'),
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
                if (price != null) Text('$price / month', style: textTheme.bodyMedium),
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
