import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/business/domain/today_summary.dart';
import 'package:mobile/features/customer/domain/booking.dart';

Booking _booking(String id, String workerId, DateTime start, [BookingStatus status = BookingStatus.confirmed]) =>
    Booking(
      id: id,
      businessId: 'biz',
      workerId: workerId,
      serviceId: 'svc',
      customerId: 'cust',
      startTime: start,
      endTime: start.add(const Duration(minutes: 30)),
      status: status,
    );

void main() {
  final now = DateTime(2026, 9, 30, 12, 0);

  test('counts today\'s non-cancelled bookings, per barber busiest first', () {
    final summary = summarizeToday([
      _booking('1', 'jane', DateTime(2026, 9, 30, 9, 0), BookingStatus.completed),
      _booking('2', 'jane', DateTime(2026, 9, 30, 15, 0)),
      _booking('3', 'mike', DateTime(2026, 9, 30, 16, 0)),
      _booking('4', 'mike', DateTime(2026, 9, 30, 17, 0), BookingStatus.cancelled),
      _booking('5', 'mike', DateTime(2026, 10, 1, 10, 0)),
    ], now);

    expect(summary.bookingsToday, 3);
    expect(summary.perWorker.map((e) => '${e.key}:${e.value}'), ['jane:2', 'mike:1']);
  });

  test('next booking is the soonest confirmed one still to come, even on a later day', () {
    final summary = summarizeToday([
      _booking('past', 'jane', DateTime(2026, 9, 30, 11, 0)),
      _booking('cancelled', 'jane', DateTime(2026, 9, 30, 13, 0), BookingStatus.cancelled),
      _booking('tomorrow', 'mike', DateTime(2026, 10, 1, 9, 0)),
      _booking('later-today', 'jane', DateTime(2026, 9, 30, 18, 0)),
    ], now);

    expect(summary.next?.id, 'later-today');
    expect(summarizeToday([_booking('tomorrow', 'mike', DateTime(2026, 10, 1, 9, 0))], now).next?.id, 'tomorrow');
  });

  test('an empty day has no count and no next booking', () {
    final summary = summarizeToday([], now);

    expect(summary.bookingsToday, 0);
    expect(summary.perWorker, isEmpty);
    expect(summary.next, isNull);
  });
}
