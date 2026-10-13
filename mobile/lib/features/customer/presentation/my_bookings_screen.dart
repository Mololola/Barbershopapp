import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/loading.dart';
import '../application/booking_controller.dart';
import '../application/review_controller.dart';
import '../domain/booking.dart';

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(myBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: bookings.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No bookings yet.'));
          }
          return ListView(
            children: [for (final booking in list) _BookingTile(booking: booking)],
          );
        },
      ),
    );
  }
}

class _BookingTile extends ConsumerWidget {
  const _BookingTile({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(bookingActionControllerProvider);
    final atRisk = ref.watch(bookingsAtRiskProvider).value ?? const {};
    final cancelledAt = booking.status == BookingStatus.confirmed ? atRisk[booking.id] : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(_formatDateTime(booking.startTime.toLocal())),
        subtitle: cancelledAt == null
            ? Text(_statusLabel(booking.status))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_statusLabel(booking.status)),
                  const SizedBox(height: 4),
                  Text(
                    shopClosureNotice(cancelledAt, DateTime.now()),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ),
        trailing: _buildTrailing(context, ref, actionState),
      ),
    );
  }

  Widget? _buildTrailing(BuildContext context, WidgetRef ref, AsyncValue<void> actionState) {
    if (booking.status == BookingStatus.confirmed) {
      return TextButton(
        onPressed: actionState.isLoading
            ? null
            : () => ref.read(bookingActionControllerProvider.notifier).cancelBooking(booking.id),
        child: const Text('Cancel'),
      );
    }

    if (booking.status == BookingStatus.completed) {
      final reviews = ref.watch(myReviewsByBookingProvider);
      return reviews.when(
        loading: () => const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (error, _) => Text('Error: $error'),
        data: (reviews) {
          if (reviews[booking.id] != null) {
            return const Text('Reviewed');
          }
          return TextButton(
            onPressed: () => context.push('/customer/bookings/${booking.id}/review'),
            child: const Text('Leave a review'),
          );
        },
      );
    }

    return null;
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

  String _formatDateTime(DateTime dt) {
    final date = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final time = TimeOfDay.fromDateTime(dt);
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$date $hour:$minute $period';
  }
}
