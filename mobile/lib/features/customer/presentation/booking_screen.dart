import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/booking_controller.dart';
import '../domain/booking.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.businessId, required this.serviceId});

  final String businessId;
  final String serviceId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  DateTime _date = DateTime.now();
  AvailableSlot? _selectedSlot;

  /// Null means "any barber".
  String? _barberId;

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
      _barberId = null;
    });
  }

  Future<void> _confirm() async {
    final slot = _selectedSlot;
    if (slot == null) return;

    final booking = await ref.read(bookingActionControllerProvider.notifier).createBooking(
          businessId: widget.businessId,
          workerId: slot.workerId,
          serviceId: widget.serviceId,
          startTime: slot.startTime,
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
        availabilityProvider((businessId: widget.businessId, serviceId: widget.serviceId, date: _date)),
      );
      setState(() => _selectedSlot = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingActionControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Book appointment')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            Row(
              children: [
                Text('Date: ${_date.toLocal().toString().split(' ').first}'),
                TextButton(onPressed: _pickDate, child: const Text('Change')),
              ],
            ),
            const SizedBox(height: 16),
            Text('Available times', style: Theme.of(context).textTheme.titleMedium),
            _buildAvailability(context),
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
                  : Text(_selectedSlot == null
                      ? 'Confirm booking'
                      : 'Confirm ${TimeOfDay.fromDateTime(_selectedSlot!.startTime.toLocal()).format(context)} '
                          'with ${_selectedSlot!.workerName}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailability(BuildContext context) {
    final availability = ref.watch(
      availabilityProvider((businessId: widget.businessId, serviceId: widget.serviceId, date: _date)),
    );
    return availability.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, _) => Text('Error: $error'),
      data: (slots) {
        if (slots.isEmpty) {
          return const Text('No available times that day.');
        }
        // Times come every 15 minutes per barber, so choosing the barber
        // first keeps the list short. Slots arrive sorted by time, then
        // barber name.
        final barbers = <String, String>{for (final slot in slots) slot.workerId: slot.workerName};
        final times = <DateTime>{};
        final shown = _barberId == null
            // "Any barber": one chip per time, booked with the first barber free then.
            ? slots.where((slot) => times.add(slot.startTime)).toList()
            : slots.where((slot) => slot.workerId == _barberId).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Any barber'),
                  selected: _barberId == null,
                  onSelected: (_) => setState(() {
                    _barberId = null;
                    _selectedSlot = null;
                  }),
                ),
                for (final entry in barbers.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _barberId == entry.key,
                    onSelected: (_) => setState(() {
                      _barberId = entry.key;
                      _selectedSlot = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in shown)
                  ChoiceChip(
                    label: Text(TimeOfDay.fromDateTime(slot.startTime.toLocal()).format(context)),
                    selected: _selectedSlot == slot,
                    onSelected: (_) => setState(() => _selectedSlot = slot),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
