import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../core/skeleton.dart';
import '../application/booking_controller.dart';
import '../application/browse_controller.dart';
import '../application/review_controller.dart';
import '../domain/booking.dart';
import 'booking_card.dart';

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(myBookingsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.myBookings),
          bottom: TabBar(tabs: [Tab(text: context.l10n.upcomingTab), Tab(text: context.l10n.pastTab)]),
        ),
        body: bookings.when(
          loading: () => const SkeletonList(),
          error: (error, _) => Center(child: Text(describeError(context.l10n, error))),
          data: (list) {
            final now = DateTime.now();
            bool isUpcoming(Booking b) => b.status == BookingStatus.confirmed && b.startTime.isAfter(now);
            // The list arrives newest first; upcoming reads soonest first.
            final upcoming = list.where(isUpcoming).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
            final past = list.where((b) => !isUpcoming(b)).toList();
            return TabBarView(
              children: [
                _BookingList(bookings: upcoming, emptyText: context.l10n.noUpcomingBookings),
                _BookingList(bookings: past, emptyText: context.l10n.noPastBookings),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  const _BookingList({required this.bookings, required this.emptyText});

  final List<Booking> bookings;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) return Center(child: Text(emptyText));
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [for (final booking in bookings) _BookingTile(booking: booking)],
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
    final business = ref.watch(businessProvider(booking.businessId)).value;

    return BookingCard(
      booking: booking,
      showDate: true,
      title: business?.name,
      currency: business?.currency,
      notice: cancelledAt == null
          ? null
          : Text(
              shopClosureNotice(context.l10n, cancelledAt, DateTime.now()),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
      action: _buildTrailing(context, ref, actionState),
    );
  }

  Widget? _buildTrailing(BuildContext context, WidgetRef ref, AsyncValue<void> actionState) {
    if (booking.status == BookingStatus.confirmed) {
      return TextButton(
        onPressed: actionState.isLoading
            ? null
            : () => ref.read(bookingActionControllerProvider.notifier).cancelBooking(booking.id),
        child: Text(context.l10n.cancel),
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
        error: (error, _) => Text(describeError(context.l10n, error)),
        data: (reviews) {
          if (reviews[booking.id] != null) {
            return Text(context.l10n.reviewed);
          }
          return TextButton(
            onPressed: () => context.push('/customer/bookings/${booking.id}/review'),
            child: Text(context.l10n.leaveAReview),
          );
        },
      );
    }

    return null;
  }
}
