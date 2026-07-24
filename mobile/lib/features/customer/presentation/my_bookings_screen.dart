import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/booking_controller.dart';
import '../domain/booking.dart';

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(myBookingsProvider);
    final actionState = ref.watch(bookingActionControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: bookings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No bookings yet.'));
          }
          return ListView(
            children: [
              for (final booking in list)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    title: Text(_formatDateTime(booking.startTime.toLocal())),
                    subtitle: Text(
                      booking.status == BookingStatus.cancelled ? 'Cancelled' : 'Confirmed',
                    ),
                    trailing: booking.status == BookingStatus.confirmed
                        ? TextButton(
                            onPressed: actionState.isLoading
                                ? null
                                : () => ref
                                    .read(bookingActionControllerProvider.notifier)
                                    .cancelBooking(booking.id),
                            child: const Text('Cancel'),
                          )
                        : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final date = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final time = TimeOfDay.fromDateTime(dt);
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$date $hour:$minute $period';
  }
}
