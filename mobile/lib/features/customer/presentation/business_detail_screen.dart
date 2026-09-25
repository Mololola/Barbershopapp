import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/loading.dart';
import '../../business/domain/business.dart';
import '../application/browse_controller.dart';

class BusinessDetailScreen extends ConsumerWidget {
  const BusinessDetailScreen({super.key, required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(businessProvider(businessId));
    final locations = ref.watch(businessLocationsProvider(businessId));
    final hours = ref.watch(businessOpeningHoursProvider(businessId));
    final services = ref.watch(businessServicesProvider(businessId));
    final workers = ref.watch(businessWorkersProvider(businessId));

    return Scaffold(
      appBar: AppBar(title: Text(business.value?.name ?? 'Barbershop')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (business.value?.logoUrl != null)
            Center(
              child: CircleAvatar(
                radius: 32,
                backgroundImage: NetworkImage(business.value!.logoUrl!),
              ),
            ),
          if (business.value?.logoUrl != null) const SizedBox(height: 16),
          Text('Locations', style: Theme.of(context).textTheme.titleMedium),
          locations.when(
            loading: () => const CircularProgressIndicator(),
            error: (error, _) => Text('Error: $error'),
            data: (list) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final l in list) Text(l.displayAddress)],
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
                    '${OpeningHours.dayNames[h.dayOfWeek]}: ${h.format(context)}',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Services', style: Theme.of(context).textTheme.titleMedium),
          services.when(
            loading: () => const LoadingView(),
            error: (error, _) => Text('Error: $error'),
            data: (list) {
              if (list.isEmpty) {
                return const Text('No services listed yet.');
              }
              final symbol = business.value == null ? '' : currencySymbol(business.value!.currency);
              return Column(
                children: [
                  for (final service in list)
                    ListTile(
                      title: Text(service.name),
                      subtitle: Text(
                        '$symbol${service.priceInMajorUnits.toStringAsFixed(2)} · ${service.durationMinutes} min',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        '/customer/businesses/$businessId/book?serviceId=${service.id}',
                      ),
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
              if (list.isEmpty) return const Text('No staff listed yet.');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final worker in list) Text(worker.name)],
              );
            },
          ),
        ],
      ),
    );
  }
}
