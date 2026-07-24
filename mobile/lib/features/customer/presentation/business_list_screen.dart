import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/browse_controller.dart';

class BusinessListScreen extends ConsumerWidget {
  const BusinessListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businesses = ref.watch(businessesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Barbershops')),
      body: businesses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No barbershops yet.'));
          }
          return ListView(
            children: [
              for (final business in list)
                ListTile(
                  title: Text(business.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/customer/businesses/${business.id}'),
                ),
            ],
          );
        },
      ),
    );
  }
}
