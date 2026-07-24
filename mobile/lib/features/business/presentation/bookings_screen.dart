import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../customer/domain/booking.dart';
import '../application/business_controller.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(businessBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
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
