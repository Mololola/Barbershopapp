import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/business_controller.dart';
import '../domain/business.dart';

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  Future<void> _showAddServiceDialog(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final durationController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add service'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
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
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(serviceControllerProvider.notifier).addService(
          name: nameController.text.trim(),
          priceCents: (double.parse(priceController.text) * 100).round(),
          durationMinutes: int.parse(durationController.text),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final currency = ref.watch(currentBusinessProvider).value?.currency;
    final symbol = currency == null ? '' : currencySymbol(currency);

    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddServiceDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: services.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No services yet — add your first one.'));
          }
          return ListView(
            children: [
              for (final service in list)
                ListTile(
                  title: Text(service.name),
                  subtitle: Text(
                    '$symbol${service.priceInMajorUnits.toStringAsFixed(2)} · ${service.durationMinutes} min',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        ref.read(serviceControllerProvider.notifier).deleteService(service.id!),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
