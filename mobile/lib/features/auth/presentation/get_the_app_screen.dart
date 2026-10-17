import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_controller.dart';

/// What a customer account sees on the website, which is for shops:
/// booking, rewards and the feed are in the phone app.
class GetTheAppScreen extends ConsumerWidget {
  const GetTheAppScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Use the app'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('This website is for barbershops.', style: textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Booking, your rewards and the feed are in the Fadra Cut app — sign in there on your phone '
            'with this same account.',
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
