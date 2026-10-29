import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n.dart';
import '../application/business_controller.dart';
import '../domain/business_subscription.dart';
import 'pay_on_website.dart';
import 'subscription_screen.dart';

/// Shown on the business home screen. Nothing renders for an active or
/// grandfathered (pre-billing) subscription — only when action is needed
/// (never subscribed, suspended, or canceled): an unpaid shop is hidden from
/// customers and deleted 60 days after the payment failed or it ended.
/// During a free trial, or once a cancellation is scheduled, it says so and
/// links to where to cancel or undo it.
class SubscriptionBanner extends ConsumerWidget {
  const SubscriptionBanner({super.key});

  Future<void> _launch(BuildContext context, Future<String> Function() action) async {
    try {
      final url = await action();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(context.l10n, error))));
      }
    }
  }

  static int _days(Duration duration) => duration.isNegative ? 0 : (duration.inHours / 24).ceil();

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
        if (sub != null && sub.grandfathered) return const SizedBox.shrink();
        if (sub != null && sub.status == SubscriptionStatus.active) {
          final String message;
          if (sub.cancelAt != null) {
            message = context.l10n.subCancelledBanner(formatSubscriptionDate(context.l10n, sub.cancelAt!));
          } else if (sub.isInTrial) {
            message = context.l10n.trialBanner(formatSubscriptionDate(context.l10n, sub.trialEndsAt!));
          } else {
            return const SizedBox.shrink();
          }
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: const Icon(Icons.event_available),
              title: Text(message),
              trailing: TextButton(
                onPressed: () => context.push('/business/subscription'),
                child: Text(context.l10n.manage),
              ),
            ),
          );
        }

        final now = DateTime.now().toUtc();
        final hiddenAt = sub?.hiddenAt;
        if (sub != null &&
            hiddenAt != null &&
            (sub.status == SubscriptionStatus.suspended || sub.status == SubscriptionStatus.canceled)) {
          final paymentFailed = sub.status == SubscriptionStatus.suspended;
          final visibility = now.isBefore(hiddenAt)
              ? context.l10n.visibleForDays(_days(hiddenAt.difference(now)))
              : context.l10n.shopHidden;
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
                  paymentFailed ? context.l10n.paymentFailed : context.l10n.subscriptionEnded,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('$visibility ${context.l10n.deletionNotice(_days(sub.suspendedAt!.add(BusinessSubscription.dataRetention).difference(now)))}'),
                const SizedBox(height: 12),
                // A failed payment is fixed in the billing portal; a canceled
                // subscription is gone in Stripe and needs a new checkout.
                if (canPayInThisApp)
                  FilledButton(
                    onPressed: () => _launch(
                      context,
                      paymentFailed
                          ? () => ref.read(billingActionControllerProvider.notifier).openPortal()
                          : () => ref.read(billingActionControllerProvider.notifier).startCheckout(),
                    ),
                    child: Text(paymentFailed ? context.l10n.updatePayment : context.l10n.subscribe),
                  )
                else
                  const PayOnWebsiteNote(),
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
              Text(context.l10n.hiddenUntilSubscribe),
              if (createdAt != null) ...[
                const SizedBox(height: 4),
                Text(context.l10n.deletionNotice(_days(createdAt.add(BusinessSubscription.dataRetention).difference(now)))),
              ],
              const SizedBox(height: 12),
              if (canPayInThisApp)
                FilledButton(
                  onPressed: () =>
                      _launch(context, () => ref.read(billingActionControllerProvider.notifier).startCheckout()),
                  child: Text(context.l10n.subscribe),
                )
              else
                const PayOnWebsiteNote(),
            ],
          ),
        );
      },
    );
  }
}
