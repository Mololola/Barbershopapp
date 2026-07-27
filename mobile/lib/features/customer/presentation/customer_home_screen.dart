import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_controller.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myProfile = ref.watch(currentProfileProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barbershop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton(
              onPressed: () => context.push('/customer/businesses'),
              child: const Text('Browse barbershops'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => context.push('/customer/my-bookings'),
              child: const Text('My bookings'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: myProfile == null ? null : () => context.push('/profile/${myProfile.id}'),
              child: const Text('Profile'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => context.push('/feed'),
              child: const Text('Feed'),
            ),
          ],
        ),
      ),
    );
  }
}
