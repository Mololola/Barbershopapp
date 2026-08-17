import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../customer/domain/booking.dart';
import '../application/business_controller.dart';
import '../domain/business.dart';
import '../domain/finance_calculator.dart';
import 'finance_access_section.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  Future<void> _showAddCostDialog(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    final labelController = TextEditingController();
    final amountController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add cost'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Label'),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Monthly amount'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Required';
                  if (double.tryParse(value) == null) return 'Enter a number';
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
    await ref.read(costItemControllerProvider.notifier).addCostItem(
          label: labelController.text.trim(),
          amountCents: (double.parse(amountController.text) * 100).round(),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final financeAccess = ref.watch(financeAccessProvider);
    final business = ref.watch(currentBusinessProvider).value;

    // Finance is a fixed bottom-nav tab now, reachable before the tool is
    // unlocked, so the gate has to live here rather than in whether the
    // entry point is shown at all.
    if (financeAccess.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final access = financeAccess.value;
    if (access == null || !access.isUnlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Finance')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: FinanceAccessSection(business: business),
        ),
      );
    }

    final costItems = ref.watch(costItemsProvider);
    final bookings = ref.watch(businessBookingsProvider);
    final services = ref.watch(servicesProvider);
    final symbol = business == null ? '' : currencySymbol(business.currency);

    return Scaffold(
      appBar: AppBar(title: const Text('Finance')),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => _showAddCostDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _SummaryCard(
            costItems: costItems,
            bookings: bookings,
            services: services,
            currencySymbol: symbol,
          ),
          const SizedBox(height: 24),
          Text('Monthly costs', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          costItems.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Error: $error'),
            data: (list) {
              if (list.isEmpty) {
                return const Text('No costs added yet — add your first one.');
              }
              return Column(
                children: [
                  for (final item in list)
                    ListTile(
                      title: Text(item.label),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$symbol${item.amountInMajorUnits.toStringAsFixed(2)}'),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => ref
                                .read(costItemControllerProvider.notifier)
                                .deleteCostItem(item.id!),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.costItems,
    required this.bookings,
    required this.services,
    required this.currencySymbol,
  });

  final AsyncValue<List<CostItem>> costItems;
  final AsyncValue<List<Booking>> bookings;
  final AsyncValue<List<Service>> services;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final costs = costItems.value;
    final bookingList = bookings.value;
    final serviceList = services.value;

    if (costs == null || bookingList == null || serviceList == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    final summary = computeFinanceSummary(
      bookings: bookingList,
      services: serviceList,
      costItems: costs,
      monthStart: monthStart,
      monthEnd: monthEnd,
      currencySymbol: currencySymbol,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This month', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Revenue: $currencySymbol${(summary.revenueCents / 100).toStringAsFixed(2)}'
                ' (${summary.completedBookingsCount} haircuts)'),
            for (final line in summary.revenueByService)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  '${line.count} × ${line.serviceName}: '
                  '$currencySymbol${(line.amountCents / 100).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Text('Costs: $currencySymbol${(summary.costsCents / 100).toStringAsFixed(2)}'),
            Text(
              'Net: ${summary.netCents < 0 ? '-' : ''}'
              '$currencySymbol${(summary.netCents.abs() / 100).toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: summary.hasBrokenEven ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            for (final line in summary.recommendations) Text('• $line'),
          ],
        ),
      ),
    );
  }
}
