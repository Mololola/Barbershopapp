import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/skeleton.dart';
import '../application/business_controller.dart';
import '../domain/business.dart';
import '../domain/finance_overview.dart';

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
                decoration: InputDecoration(labelText: context.l10n.name),
                validator: (value) => (value == null || value.trim().isEmpty) ? context.l10n.requiredField : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: priceController,
                decoration: InputDecoration(labelText: context.l10n.price),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return context.l10n.requiredField;
                  if (double.tryParse(value) == null) return context.l10n.enterANumber;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: durationController,
                decoration: InputDecoration(labelText: context.l10n.durationMinutes),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return context.l10n.requiredField;
                  if (int.tryParse(value) == null) return context.l10n.enterAWholeNumber;
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: Text(existing == null ? context.l10n.add : context.l10n.save),
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

  /// Before a new basic cut price is saved, tells an owner with a running
  /// subscription what their monthly payment becomes. True to go ahead.
  Future<bool> _confirmPriceChange(BuildContext context, WidgetRef ref, int basicCutPriceCents) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final business = await ref.read(currentBusinessProvider.future);
    if (business == null) return false;
    final ({int? currentCents, int newCents}) quote;
    try {
      quote = await ref.read(billingApiClientProvider).quoteSubscriptionPrice(business.id, basicCutPriceCents);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, error))));
      return false;
    }
    final currentCents = quote.currentCents;
    if (currentCents == null || currentCents == quote.newCents) return true;
    if (!context.mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.subscriptionChangesTitle),
        content: Text(context.l10n.subscriptionChangesBody(
          formatMoney(currentCents, business.currency),
          formatMoney(quote.newCents, business.currency),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.continueButton)),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _add(BuildContext context, WidgetRef ref, {required bool isFirst}) async {
    final values = await _showServiceDialog(
      context,
      title: isFirst ? context.l10n.yourBasicCut : context.l10n.addService,
      helper: isFirst ? context.l10n.basicCutHelper : null,
    );
    if (values == null || !context.mounted) return;
    if (isFirst && !await _confirmPriceChange(context, ref, values.priceCents)) return;
    await ref.read(serviceControllerProvider.notifier).addService(
          name: values.name,
          priceCents: values.priceCents,
          durationMinutes: values.durationMinutes,
          isFirst: isFirst,
        );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Service service) async {
    final values = await _showServiceDialog(
      context,
      title: service.isBasicCut ? context.l10n.editBasicCut : context.l10n.editService,
      existing: service,
    );
    if (values == null || !context.mounted) return;
    if (service.isBasicCut &&
        values.priceCents != service.priceCents &&
        !await _confirmPriceChange(context, ref, values.priceCents)) {
      return;
    }
    await ref.read(serviceControllerProvider.notifier).updateService(
          Service(
            id: service.id,
            businessId: service.businessId,
            name: values.name,
            priceCents: values.priceCents,
            durationMinutes: values.durationMinutes,
            isBasicCut: service.isBasicCut,
          ),
        );
  }

  Future<void> _makeBasicCut(BuildContext context, WidgetRef ref, Service service) async {
    if (!await _confirmPriceChange(context, ref, service.priceCents)) return;
    await ref.read(serviceControllerProvider.notifier).makeBasicCut(service.id!);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, Service service) async {
    if (service.isBasicCut) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.shopNeedsBasicCut),
          content: Text(context.l10n.shopNeedsBasicCutBody),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.ok))],
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.removeServiceTitle(service.name)),
        content: Text(context.l10n.removeServiceBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.remove)),
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
      appBar: AppBar(title: Text(context.l10n.services)),
      bottomNavigationBar: setupFooter,
      // Setup asks for the basic cut only; the rest come after.
      floatingActionButton: setupFooter != null && !isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => _add(context, ref, isFirst: isEmpty),
              icon: const Icon(Icons.add),
              label: Text(isEmpty ? context.l10n.addYourBasicCut : context.l10n.addService),
            ),
      body: services.when(
        loading: () => const SkeletonList(),
        error: (error, _) => Center(child: Text(describeError(context.l10n, error))),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(context.l10n.startWithBasicCut, textAlign: TextAlign.center),
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
                            context.l10n.basicCut,
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
                    tooltip: context.l10n.serviceOptions,
                    onSelected: (action) => switch (action) {
                      'edit' => _edit(context, ref, service),
                      'basic' => _makeBasicCut(context, ref, service),
                      _ => _remove(context, ref, service),
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'edit', child: Text(context.l10n.edit)),
                      if (!service.isBasicCut) PopupMenuItem(value: 'basic', child: Text(context.l10n.makeBasicCut)),
                      PopupMenuItem(value: 'remove', child: Text(context.l10n.remove)),
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
