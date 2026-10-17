import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/loading.dart';
import '../../../core/responsive.dart';
import '../../customer/application/booking_controller.dart';
import '../../customer/domain/booking.dart';
import '../application/business_controller.dart';

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(businessBookingsProvider);
    final actionState = ref.watch(bookingActionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookings'),
        actions: [
          // A desktop page stays open for hours; this fetches bookings made since.
          if (isWideLayout(context))
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(businessBookingsProvider),
            ),
        ],
      ),
      body: bookings.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No bookings yet.'));
          }

          final groups = _groupByDate(list);
          return ListView(
            children: [
              for (final entry in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    _formatDateHeader(entry.key),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                for (final booking in entry.value)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      title: Text(_formatTime(booking.startTime.toLocal())),
                      subtitle: Text(_statusLabel(booking.status)),
                      trailing: booking.status == BookingStatus.confirmed
                          ? TextButton(
                              onPressed: actionState.isLoading
                                  ? null
                                  : () async {
                                      await ref
                                          .read(bookingActionControllerProvider.notifier)
                                          .completeBooking(booking.id);
                                      ref.invalidate(businessBookingsProvider);
                                    },
                              child: const Text('Mark as done'),
                            )
                          : null,
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Keyed by date-only (local), in the same order the input list arrives
  /// (already sorted by `start_time` — see `businessBookingsProvider`), so
  /// this only needs to group consecutive-by-date, not re-sort.
  Map<DateTime, List<Booking>> _groupByDate(List<Booking> bookings) {
    final groups = <DateTime, List<Booking>>{};
    for (final booking in bookings) {
      final local = booking.startTime.toLocal();
      final dateOnly = DateTime(local.year, local.month, local.day);
      groups.putIfAbsent(dateOnly, () => []).add(booking);
    }
    return groups;
  }

  String _formatDateHeader(DateTime date) {
    final weekday = _weekdayNames[date.weekday - 1];
    final month = _monthNames[date.month - 1];
    return '$weekday, ${date.day} $month ${date.year}';
  }

  String _statusLabel(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.completed:
        return 'Completed';
    }
  }

  String _formatTime(DateTime dt) {
    final time = TimeOfDay.fromDateTime(dt);
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
