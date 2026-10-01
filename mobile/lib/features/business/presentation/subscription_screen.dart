import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/loading.dart';
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

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
    await action();
    if (!context.mounted) return;
    final state = ref.read(billingActionControllerProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error.toString())));
    }
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref, BusinessSubscription sub) async {
    final trial = sub.isInTrial;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(trial ? 'Cancel your free trial?' : 'Cancel your subscription?'),
        content: Text(
          trial
              ? 'You keep full access until ${formatSubscriptionDate(sub.trialEndsAt!)} and won\'t be charged '
                    'anything. You can change your mind any time before then.'
              : 'You keep full access until the end of the month you\'ve paid for, and won\'t be charged '
                    'again. You can change your mind any time before then.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(trial ? 'Cancel trial' : 'Cancel subscription'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _run(context, ref, () => ref.read(billingActionControllerProvider.notifier).cancelSubscription());
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
            final String title;
            final String message;
            if (sub.cancelAt != null) {
              title = sub.isInTrial ? 'Free trial cancelled' : 'Subscription cancelled';
              message =
                  'You keep full access until ${formatSubscriptionDate(sub.cancelAt!)} and won\'t be '
                  'charged. After that your shop is hidden from customers, and its data is kept for 60 days '
                  'in case you come back.';
            } else if (sub.isInTrial) {
              title = 'Free trial until ${formatSubscriptionDate(sub.trialEndsAt!)}';
              message =
                  'Nothing is charged before then. Not happy? Cancel any time before the trial ends — '
                  'you keep everything until then and pay nothing.';
            } else {
              title = 'Active';
              message =
                  'Renews every month. Cancel any time — you keep access until the end of the month '
                  'you\'ve paid for.';
            }
            children.add(
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (currency != null)
                        Text('${formatMoney(sub.monthlyAmountCents, currency)} / month', style: textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text(title, style: textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(message),
                      const SizedBox(height: 16),
                      if (sub.cancelAt != null)
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () => _run(
                                  context,
                                  ref,
                                  () => ref.read(billingActionControllerProvider.notifier).resumeSubscription(),
                                ),
                          child: const Text('Keep my subscription'),
                        )
                      else
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                          onPressed: busy ? null : () => _confirmCancel(context, ref, sub),
                          child: Text(sub.isInTrial ? 'Cancel free trial' : 'Cancel subscription'),
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
