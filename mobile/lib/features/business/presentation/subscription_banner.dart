import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/business_controller.dart';
import '../domain/business_subscription.dart';

/// Shown on the business home screen. Nothing renders for an active or
/// grandfathered (pre-billing) subscription — only when action is needed
/// (never subscribed, suspended, or canceled): an unpaid shop is hidden from
/// customers and, 60 days after that, deleted.
class SubscriptionBanner extends ConsumerWidget {
  const SubscriptionBanner({super.key});

  Future<void> _launch(BuildContext context, Future<String> Function() action) async {
    try {
      final url = await action();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    }
  }

  static String _deletionNotice(DateTime deletionAt, DateTime now) =>
      '${_days(deletionAt.difference(now))} left before your shop and all its data are permanently deleted.';

  static String _days(Duration duration) {
    final days = duration.isNegative ? 0 : (duration.inHours / 24).ceil();
    return '$days day${days == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(businessSubscriptionProvider);
    final createdAt = ref.watch(currentBusinessProvider).value?.createdAt;

    return subscription.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => const SizedBox.shrink(),
      data: (sub) {
        // sub == null means this business has never even started a
        // checkout — no business_subscriptions row exists yet (only
        // created on the first checkout attempt), so it needs the same
        // "Subscribe" prompt as an explicit 'incomplete' status, not to be
        // silently hidden — otherwise a new business could never discover
        // it needs to subscribe at all.
        if (sub != null && (sub.grandfathered || sub.status == SubscriptionStatus.active)) {
          return const SizedBox.shrink();
        }

        final now = DateTime.now().toUtc();
        final hiddenAt = sub?.hiddenAt;
        if (sub != null &&
            hiddenAt != null &&
            (sub.status == SubscriptionStatus.suspended || sub.status == SubscriptionStatus.canceled)) {
          final paymentFailed = sub.status == SubscriptionStatus.suspended;
          final visibility = now.isBefore(hiddenAt)
              ? 'Customers can still find your shop for ${_days(hiddenAt.difference(now))}.'
              : 'Your shop is hidden from customers.';
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paymentFailed ? 'Payment failed' : 'Subscription ended',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('$visibility ${_deletionNotice(hiddenAt.add(BusinessSubscription.dataRetention), now)}'),
                const SizedBox(height: 12),
                // A failed payment is fixed in the billing portal; a canceled
                // subscription is gone in Stripe and needs a new checkout.
                FilledButton(
                  onPressed: () => _launch(
                    context,
                    paymentFailed
                        ? () => ref.read(billingActionControllerProvider.notifier).openPortal()
                        : () => ref.read(billingActionControllerProvider.notifier).startCheckout(),
                  ),
                  child: Text(paymentFailed ? 'Update payment' : 'Subscribe'),
                ),
              ],
            ),
          );
        }

        // incomplete — never subscribed yet.
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your shop is hidden from customers until you subscribe.'),
              if (createdAt != null) ...[
                const SizedBox(height: 4),
                Text(_deletionNotice(createdAt.add(BusinessSubscription.dataRetention), now)),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _launch(
                  context,
                  () => ref.read(billingActionControllerProvider.notifier).startCheckout(),
                ),
                child: const Text('Subscribe'),
              ),
            ],
          ),
        );
      },
    );
  }
}
