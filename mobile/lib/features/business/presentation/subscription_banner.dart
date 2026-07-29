import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/business_controller.dart';
import '../domain/business_subscription.dart';

/// Shown on the business home screen. Nothing renders for an active or
/// grandfathered (pre-billing) subscription — only when action is needed
/// (never subscribed, suspended, or canceled).
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(businessSubscriptionProvider);

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

        if (sub != null &&
            (sub.status == SubscriptionStatus.suspended || sub.status == SubscriptionStatus.canceled)) {
          final daysLeft = sub.graceDaysRemaining ?? 0;
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
                  'Account suspended — payment failed',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('$daysLeft day${daysLeft == 1 ? '' : 's'} left before your account and its data are '
                    'permanently deleted.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _launch(
                    context,
                    () => ref.read(billingActionControllerProvider.notifier).openPortal(),
                  ),
                  child: const Text('Manage billing'),
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
              const Text('Subscribe to activate your business account.'),
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
