import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/loading.dart';
import '../application/business_controller.dart';
import '../domain/business.dart';

/// The shop's services, for its owner only. The first one is the basic cut,
/// the shop's standard haircut. What it's used for (pricing the
/// subscription, see backend/app/api/billing.py) is never shown to anyone.
class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key, this.setupFooter});

  /// Shown pinned to the bottom when this screen is a step of the
  /// onboarding wizard (see BusinessSetupScreen).
  final Widget? setupFooter;

  /// Add (no [existing]) or edit a service. Returns the entered values, or
  /// null if cancelled.
  Future<({String name, int priceCents, int durationMinutes})?> _showServiceDialog(
    BuildContext context, {
    required String title,
    String? helper,
    Service? existing,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existing?.name);
    final priceController = TextEditingController(text: existing?.priceInMajorUnits.toStringAsFixed(2));
    final durationController = TextEditingController(text: existing?.durationMinutes.toString());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (helper != null) ...[
                Text(helper, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
              ],
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Required';
                  if (double.tryParse(value) == null) return 'Enter a number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: durationController,
                decoration: const InputDecoration(labelText: 'Duration (minutes)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Required';
                  if (int.tryParse(value) == null) return 'Enter a whole number';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );

    if (confirmed != true) return null;
    return (
      name: nameController.text.trim(),
      priceCents: (double.parse(priceController.text) * 100).round(),
      durationMinutes: int.parse(durationController.text),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, {required bool isFirst}) async {
    final values = await _showServiceDialog(
      context,
      title: isFirst ? 'Your basic cut' : 'Add service',
      helper: isFirst ? 'Your standard haircut, with its price and duration.' : null,
    );
    if (values == null) return;
    await ref.read(serviceControllerProvider.notifier).addService(
          name: values.name,
          priceCents: values.priceCents,
          durationMinutes: values.durationMinutes,
        );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Service service) async {
    final values = await _showServiceDialog(
      context,
      title: service.isBasicCut ? 'Edit your basic cut' : 'Edit service',
      existing: service,
    );
    if (values == null) return;
    await ref.read(serviceControllerProvider.notifier).updateService(
          Service(
            id: service.id,
            businessId: service.businessId,
            name: values.name,
            priceCents: values.priceCents,
            durationMinutes: values.durationMinutes,
          ),
        );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, Service service, {required bool isLast}) async {
    if (service.isBasicCut && !isLast) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Choose another basic cut first'),
          content: const Text(
            'Your shop always has a basic cut. Make another service your basic cut, then remove this one.',
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${service.name}?'),
        content: Text(
          'Customers won\'t be able to book it any more. Bookings already made for it are kept.'
          '${isLast ? ' This is your last service: customers can\'t book your shop until you add one.' : ''}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(serviceControllerProvider.notifier).removeService(service.id!);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final currency = ref.watch(currentBusinessProvider).value?.currency;
    final symbol = currency == null ? '' : currencySymbol(currency);
    final theme = Theme.of(context);
    final isEmpty = services.value?.isEmpty ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      bottomNavigationBar: setupFooter,
      // Setup asks for the basic cut only; the rest come after.
      floatingActionButton: setupFooter != null && !isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => _add(context, ref, isFirst: isEmpty),
              icon: const Icon(Icons.add),
              label: Text(isEmpty ? 'Add your basic cut' : 'Add service'),
            ),
      body: services.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Start with your basic cut — your standard haircut.', textAlign: TextAlign.center),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final service in list)
                ListTile(
                  title: Row(
                    children: [
                      Flexible(child: Text(service.name, overflow: TextOverflow.ellipsis)),
                      if (service.isBasicCut) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Basic cut',
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '$symbol${service.priceInMajorUnits.toStringAsFixed(2)} · ${service.durationMinutes} min',
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Service options',
                    onSelected: (action) => switch (action) {
                      'edit' => _edit(context, ref, service),
                      'basic' => ref.read(serviceControllerProvider.notifier).makeBasicCut(service.id!),
                      _ => _remove(context, ref, service, isLast: list.length == 1),
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      if (!service.isBasicCut) const PopupMenuItem(value: 'basic', child: Text('Make basic cut')),
                      const PopupMenuItem(value: 'remove', child: Text('Remove')),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
