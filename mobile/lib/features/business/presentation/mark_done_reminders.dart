import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/offline_cache.dart';
import '../../customer/application/booking_controller.dart';
import '../../customer/domain/booking.dart';
import '../application/business_controller.dart';
import '../domain/mark_done_reminders.dart';

/// Around the shop's screens, in the app and on the website: a pop-up asks
/// to mark each booking done or a no-show as it ends, and again 15 and 30
/// minutes later. "Not now" always closes it, so the shop can keep working.
/// The phone has no push notifications, so this only shows while the app or
/// website is open; the 2-hour auto-complete covers the rest.
class MarkDoneReminders extends ConsumerStatefulWidget {
  const MarkDoneReminders({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MarkDoneReminders> createState() => _MarkDoneRemindersState();
}

class _MarkDoneRemindersState extends ConsumerState<MarkDoneReminders> {
  static const _checkEvery = Duration(minutes: 1);

  /// The last reminder shown per booking id. Kept in memory: reopening the
  /// app repeats the current one at most once.
  final _lastShown = <String, int>{};
  Timer? _timer;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_checkEvery, (_) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_asking) return;
    final business = ref.read(currentBusinessProvider).value;
    if (business == null) return;
    final now = DateTime.now();
    final List<Booking> waiting;
    try {
      waiting = await ref.read(bookingsRepositoryProvider).fetchBookingsAwaitingDone(business.id, now);
    } catch (error) {
      if (isOfflineError(error)) return;
      rethrow;
    }
    for (final booking in waiting) {
      final due = dueMarkDoneReminder(booking, now, _lastShown[booking.id]);
      if (due == null) continue;
      _lastShown[booking.id] = due;
      if (!mounted) return;
      _asking = true;
      await _ask(booking);
      _asking = false;
      return;
    }
  }

  Future<void> _ask(Booking booking) async {
    final choice = await showDialog<BookingStatus>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.markDoneReminderTitle),
        content: Text(
          context.l10n.markDoneReminderBody(
            booking.customerName ?? context.l10n.aCustomer,
            TimeOfDay.fromDateTime(booking.startTime.toLocal()).format(context),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.notNow)),
          TextButton(onPressed: () => Navigator.pop(context, BookingStatus.noShow), child: Text(context.l10n.noShow)),
          FilledButton(
            onPressed: () => Navigator.pop(context, BookingStatus.completed),
            child: Text(context.l10n.markAsDone),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    final actions = ref.read(bookingActionControllerProvider.notifier);
    if (choice == BookingStatus.noShow) {
      await actions.markNoShow(booking.id);
    } else {
      await actions.completeBooking(booking.id);
    }
    ref.invalidate(businessBookingsProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
