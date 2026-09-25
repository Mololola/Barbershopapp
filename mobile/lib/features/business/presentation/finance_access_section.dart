import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/business_controller.dart';
import '../domain/business.dart';

/// Shown on the business edit/settings screen. The dashboard only ever
/// *shows* the Finance entry once unlocked (see business_home_screen.dart);
/// starting a trial or paying happens here.
class FinanceAccessSection extends ConsumerWidget {
  const FinanceAccessSection({super.key, required this.business});

  final Business? business;

  Future<void> _startTrial(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(billingActionControllerProvider.notifier).startFinanceTrial();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    }
  }

  Future<void> _launchCheckout(BuildContext context, WidgetRef ref) async {
    try {
      final url = await ref.read(billingActionControllerProvider.notifier).startFinanceCheckout();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(financeAccessProvider).value;
    final symbol = business == null ? '' : currencySymbol(business!.currency);
    final priceCents = access?.amountCents ?? 4500;
    final priceLabel = '$symbol${(priceCents / 100).toStringAsFixed(2)}';

    Widget content;
    if (access != null && (access.grandfathered || access.paidAt != null)) {
      content = const Text('Finance tool unlocked.');
    } else if (access != null && access.isTrialActive) {
      final daysLeft = access.trialDaysRemaining ?? 0;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Free trial — $daysLeft day${daysLeft == 1 ? '' : 's'} left.'),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _launchCheckout(context, ref),
            child: Text('Pay $priceLabel to unlock permanently'),
          ),
        ],
      );
    } else if (access != null && access.trialHasExpired) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your free trial has ended.'),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => _launchCheckout(context, ref),
            child: Text('Pay $priceLabel to unlock'),
          ),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Try the finance tool free for a month, or unlock it now.'),
          const SizedBox(height: 8),
          // Wrap, not Row: two buttons side by side overflow a phone screen
          // at larger text sizes.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _startTrial(context, ref),
                child: const Text('Start free trial'),
              ),
              FilledButton(
                onPressed: () => _launchCheckout(context, ref),
                child: Text('Pay $priceLabel to unlock'),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Finance tool', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        content,
      ],
    );
  }
}
