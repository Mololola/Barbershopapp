import '../../../core/api_client.dart';
import '../domain/booking.dart';

class BookingApiClient {
  BookingApiClient(this._api);

  final ApiClient _api;

  Future<List<DateTime>> fetchAvailability({
    required String businessId,
    required String workerId,
    required String serviceId,
    required DateTime date,
  }) async {
    final result = await _api.get(
      '/businesses/$businessId/availability',
      query: {
        'worker_id': workerId,
        'service_id': serviceId,
        'date': _dateOnly(date),
      },
    );
    return (result as List).map((slot) => DateTime.parse(slot as String)).toList();
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

  String _dateOnly(DateTime date) {
    final utc = date.toUtc();
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    return '${utc.year}-$month-$day';
  }
}
