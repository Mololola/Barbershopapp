import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n.dart';
import '../../../core/loading.dart';
import '../../../core/responsive.dart';
import '../../customer/application/booking_controller.dart';
import '../../customer/domain/booking.dart';
import '../application/business_controller.dart';


class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(businessBookingsProvider);
    final actionState = ref.watch(bookingActionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.navBookings),
        actions: [
          // A desktop page stays open for hours; this fetches bookings made since.
          if (isWideLayout(context))
            IconButton(
              tooltip: context.l10n.refresh,
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(businessBookingsProvider),
            ),
        ],
      ),
      body: bookings.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text(describeError(context.l10n, error))),
        data: (list) {
          if (list.isEmpty) {
            return Center(child: Text(context.l10n.noBookingsYet));
          }

          final groups = _groupByDate(list);
          return ListView(
            children: [
              for (final entry in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    _formatDateHeader(context, entry.key),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                for (final booking in entry.value)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      title: Text(TimeOfDay.fromDateTime(booking.startTime.toLocal()).format(context)),
                      subtitle: Text(_statusLabel(context, booking.status)),
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
                              child: Text(context.l10n.markAsDone),
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

  /// "Monday, October 5, 2026" / "Lunes, 5 de octubre de 2026".
  String _formatDateHeader(BuildContext context, DateTime date) {
    final header = DateFormat.yMMMMEEEEd(context.l10n.localeName).format(date);
    return header[0].toUpperCase() + header.substring(1);
  }

  String _statusLabel(BuildContext context, BookingStatus status) => switch (status) {
        BookingStatus.confirmed => context.l10n.bookingConfirmed,
        BookingStatus.cancelled => context.l10n.bookingCancelled,
        BookingStatus.completed => context.l10n.bookingCompleted,
      };
}
