import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n.dart';
import '../../../core/responsive.dart';
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
                _BookingList(
                  bookings: upcoming,
                  empty: BookingsEmptyState(
                    text: context.l10n.noUpcomingBookings,
                    actionLabel: context.l10n.findAShop,
                    onAction: () => context.go('/customer/businesses'),
                  ),
                ),
                _BookingList(bookings: past, empty: BookingsEmptyState(text: context.l10n.noPastBookings)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BookingList extends ConsumerWidget {
  const _BookingList({required this.bookings, required this.empty});

  final List<Booking> bookings;
  final Widget empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(myBookingsProvider.future),
      child: bookings.isEmpty
          ? empty
          : isWideLayout(context)
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    TileGrid(children: [for (final booking in bookings) _BookingTile(booking: booking, margin: EdgeInsets.zero)]),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [for (final booking in bookings) _BookingTile(booking: booking)],
                ),
    );
  }
}

class _BookingTile extends ConsumerWidget {
  const _BookingTile({required this.booking, this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 4)});

  final Booking booking;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(bookingActionControllerProvider);
    final atRisk = ref.watch(bookingsAtRiskProvider).value ?? const {};
    final cancelledAt = booking.status == BookingStatus.confirmed ? atRisk[booking.id] : null;
    final business = ref.watch(businessProvider(booking.businessId)).value;

    return BookingCard(
      booking: booking,
      showDate: true,
      margin: margin,
      title: business?.name,
      currency: business?.currency,
      notice: cancelledAt == null
          ? null
          : Text(
              shopClosureNotice(context.l10n, cancelledAt, DateTime.now()),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
      action: _buildTrailing(context, ref, actionState, business?.name),
    );
  }

  /// A cancelled slot goes straight to someone else and can't be taken
  /// back, so this asks first and then says how it went.
  Future<void> _cancel(BuildContext context, WidgetRef ref, String? shopName) async {
    final l10n = context.l10n;
    final start = booking.startTime.toLocal();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cancelBookingTitle),
        content: Text(l10n.cancelBookingBody(
          TimeOfDay.fromDateTime(start).format(context),
          shopName ?? l10n.theShop,
          DateFormat.MMMMEEEEd(l10n.localeName).format(start),
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.keepIt)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.yesCancel),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // The card leaves Upcoming once the list reloads, so hold on to the
    // messenger rather than this card's context.
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(bookingActionControllerProvider.notifier).cancelBooking(booking.id);
    final state = ref.read(bookingActionControllerProvider);
    messenger.showSnackBar(SnackBar(
      content: Text(state.hasError ? describeError(l10n, state.error) : l10n.bookingCancelledToast),
    ));
  }

  Widget? _buildTrailing(BuildContext context, WidgetRef ref, AsyncValue<void> actionState, String? shopName) {
    if (booking.status == BookingStatus.confirmed && booking.startTime.isAfter(DateTime.now())) {
      return TextButton(
        onPressed: actionState.isLoading ? null : () => _cancel(context, ref, shopName),
        child: Text(context.l10n.cancelBooking),
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
