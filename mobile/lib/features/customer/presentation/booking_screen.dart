import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/booking_controller.dart';
import '../application/browse_controller.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.businessId, required this.serviceId});

  final String businessId;
  final String serviceId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  String? _workerId;
  DateTime _date = DateTime.now();
  DateTime? _selectedSlot;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
      _selectedSlot = null;
    });
  }

  Future<void> _confirm() async {
    final workerId = _workerId;
    final slot = _selectedSlot;
    if (workerId == null || slot == null) return;

    final booking = await ref.read(bookingActionControllerProvider.notifier).createBooking(
          businessId: widget.businessId,
          workerId: workerId,
          serviceId: widget.serviceId,
          startTime: slot,
        );

    if (!mounted) return;
    if (booking != null) {
      // Clear the browse/booking flow off the stack first so "back" from My
      // Bookings goes straight to Customer home, not back through booking.
      context.go('/customer');
      context.push('/customer/my-bookings');
    } else {
      // On conflict (slot just taken), refresh availability so the stale slot disappears.
      ref.invalidate(
        availabilityProvider((
          businessId: widget.businessId,
          workerId: workerId,
          serviceId: widget.serviceId,
          date: _date,
        )),
      );
      setState(() => _selectedSlot = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workers = ref.watch(businessWorkersProvider(widget.businessId));
    final bookingState = ref.watch(bookingActionControllerProvider);

    // Built before reading `_workerId` below — `data` sets a default the
    // first time the list loads, and that default must be visible to the
    // rest of this build, not just the next one.
    final workerPicker = workers.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, _) => Text('Error: $error'),
      data: (list) {
        if (list.isEmpty) {
          return const Text('No staff available to book with yet.');
        }
        _workerId ??= list.first.id;
        return DropdownButton<String>(
          value: _workerId,
          items: [
            for (final worker in list) DropdownMenuItem(value: worker.id, child: Text(worker.name)),
          ],
          onChanged: (value) => setState(() {
            _workerId = value;
            _selectedSlot = null;
          }),
        );
      },
    );
    final workerId = _workerId;

    return Scaffold(
      appBar: AppBar(title: const Text('Book appointment')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            Text('Barber', style: Theme.of(context).textTheme.titleMedium),
            workerPicker,
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Date: ${_date.toLocal().toString().split(' ').first}'),
                TextButton(onPressed: _pickDate, child: const Text('Change')),
              ],
            ),
            const SizedBox(height: 16),
            if (workerId != null) ...[
              Text('Available times', style: Theme.of(context).textTheme.titleMedium),
              _buildAvailability(context, workerId),
            ],
            const SizedBox(height: 24),
            if (bookingState.hasError)
              Text(
                bookingState.error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            FilledButton(
              onPressed: (_selectedSlot == null || bookingState.isLoading) ? null : _confirm,
              child: bookingState.isLoading
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Confirm booking'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailability(BuildContext context, String workerId) {
    final availability = ref.watch(
      availabilityProvider((
        businessId: widget.businessId,
        workerId: workerId,
        serviceId: widget.serviceId,
        date: _date,
      )),
    );
    return availability.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, _) => Text('Error: $error'),
      data: (slots) {
        if (slots.isEmpty) {
          return const Text('No available times that day.');
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final slot in slots)
              ChoiceChip(
                label: Text(TimeOfDay.fromDateTime(slot.toLocal()).format(context)),
                selected: _selectedSlot == slot,
                onSelected: (_) => setState(() => _selectedSlot = slot),
              ),
          ],
        );
      },
    );
  }
}
