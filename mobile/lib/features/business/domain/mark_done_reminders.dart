import '../../customer/domain/booking.dart';

/// The shop is reminded as a booking ends, then 15 and 30 minutes later.
/// Two hours after it ends the database marks it done itself (the
/// auto_complete_bookings job).
const markDoneReminderOffsets = [Duration.zero, Duration(minutes: 15), Duration(minutes: 30)];

/// Which reminder (an index into [markDoneReminderOffsets]) is due now, or
/// null when there's none newer than [lastShown]. A shop that opens the app
/// late gets only the latest one, not all of them in a row.
int? dueMarkDoneReminder(Booking booking, DateTime now, int? lastShown) {
  final sinceEnd = now.difference(booking.endTime);
  final due = markDoneReminderOffsets.lastIndexWhere((offset) => sinceEnd >= offset);
  if (due < 0 || (lastShown != null && lastShown >= due)) return null;
  return due;
}
