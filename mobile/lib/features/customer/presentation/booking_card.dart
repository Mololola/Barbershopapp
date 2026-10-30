import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n.dart';
import '../../../core/theme.dart';
import '../../business/domain/finance_overview.dart';
import '../domain/booking.dart';

/// One booking as either side sees it: [title] is the shop for a customer
/// and the customer for a shop. [showDate] is off where rows are already
/// grouped under a date header.
class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    required this.showDate,
    this.title,
    this.currency,
    this.notice,
    this.action,
  });

  final Booking booking;
  final bool showDate;
  final String? title;
  final String? currency;
  final Widget? notice;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final start = booking.startTime.toLocal();
    final times =
        '${TimeOfDay.fromDateTime(start).format(context)}–${TimeOfDay.fromDateTime(booking.endTime.toLocal()).format(context)}';
    final date = DateFormat.MMMEd(l10n.localeName).format(start);
    final details = [
      if (booking.serviceName != null) booking.serviceName!,
      if (booking.workerName != null) l10n.withBarber(booking.workerName!),
      l10n.minutesShort(booking.endTime.difference(booking.startTime).inMinutes),
      if (booking.priceCents != null && currency != null) formatMoney(booking.priceCents!, currency!),
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    showDate ? '${date[0].toUpperCase()}${date.substring(1)} · $times' : times,
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusLabel(booking.status),
              ],
            ),
            if (title != null) ...[
              const SizedBox(height: 2),
              Text(title!, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 2),
            Text(details, style: const TextStyle(color: AppColors.steel)),
            if (notice != null) ...[const SizedBox(height: 6), notice!],
            if (action != null) Align(alignment: AlignmentDirectional.centerEnd, child: action),
          ],
        ),
      ),
    );
  }
}

/// An empty bookings tab: what will show here, and the one thing to do
/// about it. Scrollable so pull-to-refresh still works on it.
class BookingsEmptyState extends StatelessWidget {
  const BookingsEmptyState({super.key, required this.text, this.hint, this.actionLabel, this.onAction});

  final String text;
  final String? hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
      children: [
        const Icon(Icons.event_available_outlined, color: AppColors.brass, size: 40),
        const SizedBox(height: 12),
        Text(text, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(hint!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.steel)),
        ],
        if (actionLabel != null) ...[
          const SizedBox(height: 20),
          Center(child: FilledButton(onPressed: onAction, child: Text(actionLabel!))),
        ],
      ],
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel(this.status);

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      // Brass text on the light card is too faint to read (about 3.4:1).
      BookingStatus.confirmed => (context.l10n.bookingConfirmed, AppColors.charcoal),
      BookingStatus.completed => (context.l10n.bookingCompleted, AppColors.steel),
      BookingStatus.cancelled => (context.l10n.bookingCancelled, Theme.of(context).colorScheme.error),
    };
    return Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600));
  }
}
