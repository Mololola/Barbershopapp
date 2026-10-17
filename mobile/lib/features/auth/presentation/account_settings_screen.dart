import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../business/application/business_controller.dart';
import '../../business/domain/finance_overview.dart';
import '../application/auth_controller.dart';
import '../domain/profile.dart';

/// The one ⚙️ screen for managing an account — reached from the home
/// screen's gear and from the gear on your own profile.
class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).signOut();
  }

  /// True to go on deleting. Unpaid rewards are offered as a cash-out first;
  /// deleting gives them up.
  Future<bool> _confirmGivingUpRewards(BuildContext context, WidgetRef ref) async {
    final List<({String currency, int amountCents})> unpaid;
    try {
      unpaid = await ref.read(accountApiClientProvider).fetchUnpaidRewards();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return false;
    }
    if (unpaid.isEmpty) return true;
    if (!context.mounted) return false;
    final amounts = unpaid.map((balance) => formatMoney(balance.amountCents, balance.currency)).join(' and ');
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('You have rewards not paid out yet'),
        content: Text(
          'You have $amounts that hasn\'t been paid to you. Cash it out first, or delete your account and give '
          'it up — it can\'t be paid after your account is gone.',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, 'give-up'),
            child: const Text('Give it up'),
          ),
          FilledButton(onPressed: () => Navigator.pop(context, 'cash-out'), child: const Text('Cash out')),
        ],
      ),
    );
    if (choice == 'cash-out' && context.mounted) context.push('/rewards');
    return choice == 'give-up';
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    if (!await _confirmGivingUpRewards(context, ref) || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your account and everything tied to it — profile, bookings, '
          'reviews, posts, messages. This can\'t be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(authControllerProvider.notifier).deleteAccount();
    if (!context.mounted) return;

    final state = ref.read(authControllerProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error.toString())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final isBusiness = profile?.role == AccountRole.business;
    final business = isBusiness ? ref.watch(currentBusinessProvider).value : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          if (isBusiness) ...[
            const _GroupHeader('Your shop'),
            ListTile(
              leading: const Icon(Icons.brush_outlined),
              title: const Text('Shop page'),
              subtitle: const Text('Logo, cover photo and brand colour'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/business/shop/edit'),
            ),
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Business details'),
              subtitle: const Text('Locations and opening hours'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/business/edit'),
            ),
            ListTile(
              leading: const Icon(Icons.content_cut),
              title: const Text('Services'),
              subtitle: const Text('What you offer, prices and durations'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/business/services'),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Subscription & billing'),
              subtitle: const Text('Your plan, free trial, cancel, invoices'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/business/subscription'),
            ),
            // Set at signup and never editable: the referrer is paid from it.
            if (business != null)
              ListTile(
                leading: const Icon(Icons.card_giftcard_outlined),
                title: const Text('Referred by'),
                subtitle: Text(business.referredByCode ?? 'No referral code was used'),
              ),
          ] else if (profile != null) ...[
            const _GroupHeader('Your profile'),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Profile photo'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/profile/edit'),
            ),
            // Worker features aren't available to under-18 accounts.
            if (profile.isMinor != true)
              ListTile(
                leading: const Icon(Icons.content_cut),
                title: const Text('Worker profile'),
                subtitle: const Text('Legal name, bio and availability to work at a shop'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/customer/worker-profile'),
              ),
          ],
          // Only customers refer shops; businesses see who referred them.
          if (profile != null && !isBusiness)
            ListTile(
              leading: const Icon(Icons.card_giftcard_outlined),
              title: const Text('Your referral code'),
              subtitle: Text(profile.referralCode),
              trailing: const Icon(Icons.copy),
              onTap: () {
                Clipboard.setData(ClipboardData(text: profile.referralCode));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral code copied')));
              },
            ),
          const _GroupHeader('Account'),
          if (profile?.isAdmin == true)
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Admin'),
              subtitle: const Text('Dashboard, customers, businesses, payouts'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/admin'),
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: authState.isLoading ? null : () => _signOut(context, ref),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
            title: Text('Delete account', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            subtitle: const Text('Permanently deletes your account and all its data'),
            onTap: authState.isLoading ? null : () => _deleteAccount(context, ref),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}
