import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/booking.dart';

/// Direct Supabase reads (RLS-permitted — see docs/architecture.md) for
/// bookings already created via [BookingApiClient]. Writes always go
/// through FastAPI; this only ever reads.
class BookingsRepository {
  BookingsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Booking>> fetchMyBookings(String customerId) async {
    final rows = await _client
        .from('bookings')
        .select()
        .eq('customer_id', customerId)
        .order('start_time', ascending: false);
    return rows.map(Booking.fromSupabaseRow).toList();
  }

  Future<List<Booking>> fetchBusinessBookings(String businessId) async {
    final rows = await _client
        .from('bookings')
        .select()
        .eq('business_id', businessId)
        .order('start_time');
    return rows.map(Booking.fromSupabaseRow).toList();
  }

  Future<Booking?> fetchBooking(String bookingId) async {
    final row = await _client.from('bookings').select().eq('id', bookingId).maybeSingle();
    if (row == null) return null;
    return Booking.fromSupabaseRow(row);
  }

  /// Drives the mandatory-review router gate in `core/router.dart` — the
  /// oldest completed booking that doesn't have a `reviews` row yet.
  /// `reviews` is unique on `booking_id`, so PostgREST embeds it as a
  /// nullable object (`null` or a map), not a list — casting it as a List
  /// throws, which silently degraded this to "never gates" (see the bug
  /// this fixed: the resulting AsyncError's `.value` just reads as null).
  Future<Booking?> fetchOldestUnreviewedCompletedBooking(String customerId) async {
    final rows = await _client
        .from('bookings')
        .select('*, reviews(id)')
        .eq('customer_id', customerId)
        .eq('status', 'completed')
        .order('start_time');
    for (final row in rows) {
      if (row['reviews'] == null) return Booking.fromSupabaseRow(row);
    }
    return null;
  }
}
