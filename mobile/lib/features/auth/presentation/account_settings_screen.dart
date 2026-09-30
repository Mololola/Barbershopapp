import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../business/application/business_controller.dart';
import '../application/auth_controller.dart';
import '../domain/profile.dart';

/// The one ⚙️ screen for managing an account — reached from the home
/// screen's gear and from the gear on your own profile.
class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).signOut();
  }

  Future<void> _openBilling(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await ref.read(billingActionControllerProvider.notifier).openPortal();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      // e.g. "No billing account yet — subscribe first" from the backend.
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
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
              subtitle: const Text('Locations, opening hours, finance tool'),
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
              subtitle: const Text('Payment method, invoices, cancel'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => _openBilling(context, ref),
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
          if (profile != null)
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
