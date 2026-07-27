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
    final services = ref.watch(servicesProvider);
    final workers = ref.watch(workersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barbershop for Business'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/business/edit'),
          ),
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
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: business.logoUrl != null ? NetworkImage(business.logoUrl!) : null,
                    child: business.logoUrl == null ? const Icon(Icons.storefront, size: 32) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(business.name, style: Theme.of(context).textTheme.headlineSmall),
                        if (business.phone != null) Text('Phone: ${business.phone}'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              Text('Services', style: Theme.of(context).textTheme.titleMedium),
              services.when(
                loading: () => const CircularProgressIndicator(),
                error: (error, _) => Text('Error: $error'),
                data: (list) {
                  if (list.isEmpty) return const Text('No services listed yet.');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final service in list)
                        Text(
                          '${service.name} — ${currencySymbol(business.currency)}'
                          '${service.priceInMajorUnits.toStringAsFixed(2)}',
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Text('Staff', style: Theme.of(context).textTheme.titleMedium),
              workers.when(
                loading: () => const CircularProgressIndicator(),
                error: (error, _) => Text('Error: $error'),
                data: (list) {
                  if (list.isEmpty) return const Text('No staff yet.');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [for (final worker in list) Text(worker.name)],
                  );
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.push('/business/bookings'),
                child: const Text('Bookings'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => context.push('/feed'),
                child: const Text('Feed'),
              ),
            ],
          );
        },
      ),
    );
  }
}
