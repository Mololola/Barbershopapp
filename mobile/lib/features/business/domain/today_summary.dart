import '../../customer/domain/booking.dart';

/// The business home screen's "today" card: how busy the day is, per
/// barber, and what's coming next.
class TodaySummary {
  const TodaySummary({required this.bookingsToday, required this.perWorker, required this.next});

  /// Confirmed or completed bookings starting today (cancelled ones don't count).
  final int bookingsToday;

  /// Today's bookings by worker id, busiest first.
  final List<MapEntry<String, int>> perWorker;

  /// The soonest confirmed booking that hasn't started yet — today or later.
  final Booking? next;
}

TodaySummary summarizeToday(List<Booking> bookings, DateTime now) {
  final localNow = now.toLocal();
  bool isToday(DateTime time) {
    final local = time.toLocal();
    return local.year == localNow.year && local.month == localNow.month && local.day == localNow.day;
  }

  final today = bookings.where((b) => b.status != BookingStatus.cancelled && isToday(b.startTime));
  final perWorker = <String, int>{};
  for (final booking in today) {
    perWorker.update(booking.workerId, (count) => count + 1, ifAbsent: () => 1);
  }

  Booking? next;
  for (final booking in bookings) {
    if (booking.status != BookingStatus.confirmed || !booking.startTime.isAfter(now)) continue;
    if (next == null || booking.startTime.isBefore(next.startTime)) next = booking;
  }

  return TodaySummary(
    bookingsToday: today.length,
    perWorker: perWorker.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    next: next,
  );
}
