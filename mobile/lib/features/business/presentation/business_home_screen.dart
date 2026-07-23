import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_controller.dart';
import '../application/business_controller.dart';
import '../domain/business.dart';

class BusinessHomeScreen extends ConsumerWidget {
  const BusinessHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(currentBusinessProvider);
    final locations = ref.watch(locationsProvider);
    final hours = ref.watch(openingHoursProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barbershop for Business'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: business.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (business) {
          if (business == null) {
            return const Center(child: Text('No business found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(business.name, style: Theme.of(context).textTheme.headlineSmall),
              if (business.phone != null) Text('Phone: ${business.phone}'),
              const SizedBox(height: 16),
              Text('Locations', style: Theme.of(context).textTheme.titleMedium),
              locations.when(
                loading: () => const CircularProgressIndicator(),
                error: (error, _) => Text('Error: $error'),
                data: (list) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final l in list) Text('${l.addressLine}, ${l.city}')],
                ),
              ),
              const SizedBox(height: 16),
              Text('Opening hours', style: Theme.of(context).textTheme.titleMedium),
              hours.when(
                loading: () => const CircularProgressIndicator(),
                error: (error, _) => Text('Error: $error'),
                data: (list) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final h in list)
                      Text(
                        '${OpeningHours.dayNames[h.dayOfWeek]}: '
                        '${h.isClosed ? 'Closed' : '${h.openTime?.format(context)} – ${h.closeTime?.format(context)}'}',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.push('/business/services'),
                child: const Text('Manage services'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => context.push('/business/staff'),
                child: const Text('Manage staff'),
              ),
            ],
          );
        },
      ),
    );
  }
}
