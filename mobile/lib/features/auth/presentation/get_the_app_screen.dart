import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../application/auth_controller.dart';

/// What a customer account sees on the website, which is for shops:
/// booking, rewards and the feed are in the phone app.
class GetTheAppScreen extends ConsumerWidget {
  const GetTheAppScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.useTheAppTitle), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(context.l10n.websiteIsForShops, style: textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            context.l10n.useTheAppBody,
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            child: Text(context.l10n.signOut),
          ),
        ],
      ),
    );
  }
}
