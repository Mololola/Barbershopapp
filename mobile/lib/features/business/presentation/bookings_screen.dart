import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n.dart';
import '../../../core/responsive.dart';
import '../../../core/skeleton.dart';
import '../../customer/application/booking_controller.dart';
import '../../customer/domain/booking.dart';
import '../../customer/presentation/booking_card.dart';
import '../application/business_controller.dart';


class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(businessBookingsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          bottom: TabBar(tabs: [Tab(text: context.l10n.upcomingTab), Tab(text: context.l10n.pastTab)]),
        ),
        body: bookings.when(
          loading: () => const SkeletonList(),
          error: (error, _) => Center(child: Text(describeError(context.l10n, error))),
          data: (list) {
            // Upcoming starts with all of today, so a cut that has just
            // happened is still there to mark done.
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final upcoming = list.where((b) => !b.startTime.toLocal().isBefore(today)).toList();
            final past = list.where((b) => b.startTime.toLocal().isBefore(today)).toList().reversed.toList();
            return TabBarView(
              children: [
                _DayGroupedList(
                  bookings: upcoming,
                  today: today,
                  empty: BookingsEmptyState(
                    text: context.l10n.noUpcomingBookings,
                    hint: context.l10n.noUpcomingBookingsShopHint,
                    actionLabel: context.l10n.editShopPage,
                    onAction: () => context.push('/business/shop/edit'),
                  ),
                ),
                _DayGroupedList(
                  bookings: past,
                  today: today,
                  empty: BookingsEmptyState(text: context.l10n.noPastBookings),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DayGroupedList extends ConsumerWidget {
  const _DayGroupedList({required this.bookings, required this.today, required this.empty});

  /// Already in display order.
  final List<Booking> bookings;
  final DateTime today;
  final Widget empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      // New bookings arrive from customers at any time; pull to catch up.
      onRefresh: () => ref.refresh(businessBookingsProvider.future),
      child: bookings.isEmpty ? empty : _list(context, ref),
    );
  }

  Widget _list(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(bookingActionControllerProvider);
    final currency = ref.watch(currentBusinessProvider).value?.currency;
    final groups = _groupByDate(bookings);
    // On the website a day's bookings sit side by side, so a busy day fits
    // on screen at the desk.
    final wide = isWideLayout(context);
    final cardMargin = wide ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16, vertical: 4);
    Widget card(Booking booking) => BookingCard(
          booking: booking,
          showDate: false,
          title: booking.customerName,
          currency: currency,
          margin: cardMargin,
          // Marking done asks the customer for a review, so not before the cut starts.
          action: booking.status == BookingStatus.confirmed && booking.startTime.isBefore(DateTime.now())
              ? Wrap(
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                      onPressed: actionState.isLoading
                          ? null
                          : () async {
                              await ref.read(bookingActionControllerProvider.notifier).markNoShow(booking.id);
                              ref.invalidate(businessBookingsProvider);
                            },
                      child: Text(context.l10n.noShow),
                    ),
                    TextButton(
                      onPressed: actionState.isLoading
                          ? null
                          : () async {
                              await ref.read(bookingActionControllerProvider.notifier).completeBooking(booking.id);
                              ref.invalidate(businessBookingsProvider);
                            },
                      child: Text(context.l10n.markAsDone),
                    ),
                  ],
                )
              : null,
        );
    final sidePadding = wide ? 24.0 : 16.0;
    return ListView(
      padding: EdgeInsets.only(bottom: wide ? 24 : 8),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(sidePadding, 16, sidePadding, wide ? 8 : 4),
            child: Text(
              entry.key == today
                  ? '${context.l10n.today} · ${_formatDateHeader(context, entry.key)}'
                  : _formatDateHeader(context, entry.key),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (wide)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: sidePadding),
              child: TileGrid(children: [for (final booking in entry.value) card(booking)]),
            )
          else
            for (final booking in entry.value) card(booking),
        ],
      ],
    );
  }

  /// Keyed by date-only (local), in the order the list arrives (sorted by
  /// `start_time`, reversed for Past), so this only groups, never re-sorts.
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
}
