import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/loading.dart';
import '../../../core/theme.dart';
import '../application/business_controller.dart';
import '../domain/business_subscription.dart';
import '../domain/finance_overview.dart';
import 'subscription_banner.dart';

const _monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "26 Oct 2026", in the phone's time zone.
String formatSubscriptionDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day} ${_monthShort[local.month - 1]} ${local.year}';
}

/// Settings › Subscription & billing: the plan, the trial, and a cancel
/// button that's easy to find — cancelling (always at the end of the trial
/// or paid month) is done here; card and invoices live in Stripe's portal.
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

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref, BusinessSubscription sub) async {
    // A trial isn't cancelled on its own: cancelling ends the subscription
    // when the trial (or paid month) runs out, and the shop is hidden until
    // the owner subscribes again.
    final until = sub.isInTrial
        ? 'Your free trial still runs until ${formatSubscriptionDate(sub.trialEndsAt!)}'
        : 'You keep full access until the end of the month you\'ve paid for';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel your subscription?'),
        content: Text(
          '$until and won\'t be charged again. After that your shop is hidden from customers until you '
          'subscribe again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel subscription'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subscribe again?'),
        content: Text(
          sub.isInTrial
              ? 'Your free trial continues until ${formatSubscriptionDate(sub.trialEndsAt!)}. After that, '
                    '$plan is charged to the card you already added.'
              : 'We\'ll keep charging $plan to the card you already added. Nothing extra is charged today.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Subscribe')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(billingActionControllerProvider.notifier).resumeSubscription(),
      'You\'re subscribed again',
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(businessSubscriptionProvider);
    final currency = ref.watch(currentBusinessProvider).value?.currency;
    final busy = ref.watch(billingActionControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: subscription.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (sub) {
          final textTheme = Theme.of(context).textTheme;
          final children = <Widget>[];

          if (sub != null && sub.grandfathered) {
            children.add(const Text('Your shop has free access — there\'s nothing to pay.'));
          } else if (sub == null || sub.status != SubscriptionStatus.active) {
            children.add(const SubscriptionBanner());
          } else {
            final price = currency == null ? null : formatMoney(sub.monthlyAmountCents, currency);
            final String badge;
            final Color badgeColor;
            final String title;
            final String message;
            if (sub.cancelAt != null) {
              badge = 'Cancelled';
              badgeColor = AppColors.rust;
              title = 'Ends ${formatSubscriptionDate(sub.cancelAt!)}';
              message =
                  'Your shop stays visible to customers until then and you won\'t be charged again. After '
                  'that it\'s hidden until you subscribe again, and its data is kept for 60 days.';
            } else if (sub.isInTrial) {
              badge = 'Free trial';
              badgeColor = AppColors.brass;
              title = 'Free trial until ${formatSubscriptionDate(sub.trialEndsAt!)}';
              message =
                  'Nothing is charged before then. After that it renews every month — cancel any time '
                  'before the trial ends and you pay nothing.';
            } else {
              badge = 'Active';
              badgeColor = AppColors.brass;
              title = 'Renews every month';
              message = 'Cancel any time — you keep access until the end of the month you\'ve paid for.';
            }
            children.add(
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(999)),
                            child: Text(
                              badge,
                              style: textTheme.labelMedium?.copyWith(
                                color: badgeColor == AppColors.rust ? AppColors.onRust : AppColors.onBrass,
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
                      if (sub.cancelAt != null)
                        FilledButton(
                          onPressed: busy ? null : () => _confirmResubscribe(context, ref, sub, price),
                          child: const Text('Subscribe again'),
                        )
                      else
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                          onPressed: busy ? null : () => _confirmCancel(context, ref, sub),
                          child: const Text('Cancel subscription'),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...children,
              if (sub?.status == SubscriptionStatus.active && sub?.grandfathered == false) ...[
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
          );
        },
      ),
    );
  }
}
