import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_language.dart';
import '../../../core/l10n.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(context.l10n, error))));
      }
      return false;
    }
    if (unpaid.isEmpty) return true;
    if (!context.mounted) return false;
    final amounts = unpaid.map((balance) => formatMoney(balance.amountCents, balance.currency)).join(context.l10n.listAnd);
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.unpaidRewardsTitle),
        content: Text(context.l10n.unpaidRewardsBody(amounts)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, 'give-up'),
            child: Text(context.l10n.giveItUp),
          ),
          FilledButton(onPressed: () => Navigator.pop(context, 'cash-out'), child: Text(context.l10n.cashOut)),
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
        title: Text(context.l10n.deleteAccountTitle),
        content: Text(context.l10n.deleteAccountBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.deleteAccount),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(authControllerProvider.notifier).deleteAccount();
    if (!context.mounted) return;

    final state = ref.read(authControllerProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(context.l10n, state.error))));
    }
  }

  /// Language names are written in their own language, so anyone can find
  /// theirs whatever the app is showing.
  String _languageName(BuildContext context, Locale? locale) => switch (locale?.languageCode) {
        'en' => 'English',
        'es' => 'Español',
        _ => context.l10n.phoneLanguage,
      };

  Future<void> _chooseLanguage(BuildContext context, WidgetRef ref) async {
    final current = ref.read(appLanguageProvider);
    final options = <Locale?>[null, const Locale('en'), const Locale('es')];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(context.l10n.language),
        children: [
          for (final option in options)
            ListTile(
              title: Text(_languageName(context, option)),
              trailing: option?.languageCode == current?.languageCode ? const Icon(Icons.check) : null,
              onTap: () {
                ref.read(appLanguageProvider.notifier).choose(option);
                Navigator.pop(dialogContext);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final isBusiness = profile?.role == AccountRole.business;
    final business = isBusiness ? ref.watch(currentBusinessProvider).value : null;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: ListView(
        children: [
          if (isBusiness) ...[
            _GroupHeader(context.l10n.yourShopGroup),
            ListTile(
              leading: const Icon(Icons.brush_outlined),
              title: Text(context.l10n.shopPage),
              subtitle: Text(context.l10n.shopPageSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/business/shop/edit'),
            ),
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: Text(context.l10n.businessDetails),
              subtitle: Text(context.l10n.businessDetailsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/business/edit'),
            ),
            ListTile(
              leading: const Icon(Icons.content_cut),
              title: Text(context.l10n.services),
              subtitle: Text(context.l10n.servicesSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/business/services'),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(context.l10n.subscriptionBilling),
              subtitle: Text(context.l10n.subscriptionBillingSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/business/subscription'),
            ),
            // Set at signup and never editable: the referrer is paid from it.
            if (business != null)
              ListTile(
                leading: const Icon(Icons.card_giftcard_outlined),
                title: Text(context.l10n.referredBy),
                subtitle: Text(business.referredByCode ?? context.l10n.noReferralCodeUsed),
              ),
          ] else if (profile != null) ...[
            _GroupHeader(context.l10n.yourProfileGroup),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(context.l10n.profilePhoto),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/profile/edit'),
            ),
            // Worker features aren't available to under-18 accounts.
            if (profile.isMinor != true)
              ListTile(
                leading: const Icon(Icons.content_cut),
                title: Text(context.l10n.workerProfile),
                subtitle: Text(context.l10n.workerProfileSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/customer/worker-profile'),
              ),
          ],
          // Only customers refer shops; businesses see who referred them.
          if (profile != null && !isBusiness)
            ListTile(
              leading: const Icon(Icons.card_giftcard_outlined),
              title: Text(context.l10n.yourReferralCode),
              subtitle: Text(profile.referralCode),
              trailing: const Icon(Icons.copy),
              onTap: () {
                Clipboard.setData(ClipboardData(text: profile.referralCode));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.referralCodeCopied)));
              },
            ),
          _GroupHeader(context.l10n.accountGroup),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(context.l10n.language),
            subtitle: Text(_languageName(context, ref.watch(appLanguageProvider))),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _chooseLanguage(context, ref),
          ),
          if (profile?.isAdmin == true)
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: Text(context.l10n.adminEntry),
              subtitle: Text(context.l10n.adminEntrySubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/admin'),
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(context.l10n.signOut),
            onTap: authState.isLoading ? null : () => _signOut(context, ref),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
            title: Text(context.l10n.deleteAccount, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            subtitle: Text(context.l10n.deleteAccountSubtitle),
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
