import '../../../core/api_client.dart';
import '../../rewards/domain/reward_credit.dart';
import '../domain/booking.dart';

class BookingApiClient {
  BookingApiClient(this._api);

  final ApiClient _api;

  Future<List<AvailableSlot>> fetchAvailability({
    required String businessId,
    required String serviceId,
    required DateTime date,
  }) async {
    final result = await _api.get(
      '/businesses/$businessId/availability',
      query: {
        'service_id': serviceId,
        'date': _dateOnly(date),
      },
    );
    return (result as List)
        .map((slot) => AvailableSlot.fromApiJson(slot as Map<String, dynamic>))
        .toList();
  }

  Future<Booking> createBooking({
    required String businessId,
    required String workerId,
    required String serviceId,
    required DateTime startTime,
  }) async {
    final result = await _api.post(
      '/bookings',
      body: {
        'business_id': businessId,
        'worker_id': workerId,
        'service_id': serviceId,
        'start_time': startTime.toUtc().toIso8601String(),
      },
    );
    return Booking.fromApiJson(result as Map<String, dynamic>);
  }

  Future<Booking> cancelBooking(String bookingId) async {
    final result = await _api.post('/bookings/$bookingId/cancel');
    return Booking.fromApiJson(result as Map<String, dynamic>);
  }

  /// Business-side action — only the owning business can call this.
  Future<Booking> completeBooking(String bookingId) async {
    final result = await _api.post('/bookings/$bookingId/complete');
    return Booking.fromApiJson(result as Map<String, dynamic>);
  }

  /// My upcoming bookings that will be cancelled with their shop if it
  /// doesn't renew, by booking id → when that happens.
  Future<Map<String, DateTime>> fetchBookingsAtRisk() async {
    final result = await _api.get('/me/bookings/at-risk');
    return {
      for (final row in result as List)
        row['booking_id'] as String: DateTime.parse(row['cancelled_at'] as String),
    };
  }

  Future<RewardCredit> creditReviewReward(String bookingId) async {
    final result = await _api.post('/bookings/$bookingId/credit-review-reward');
    return RewardCredit.fromApiJson(result as Map<String, dynamic>);
  }

  String _dateOnly(DateTime date) {
    // `date` is a calendar-day value from the date picker (local midnight),
    // not a specific instant — converting to UTC here shifted it a day back
    // for any positive UTC offset, silently querying (and then booking) the
    // wrong day's slots while the on-screen date label stayed correct.
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
