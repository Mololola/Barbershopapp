import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline_cache.dart';
import '../domain/booking.dart';

/// Direct Supabase reads (RLS-permitted — see docs/architecture.md) for
/// bookings already created via [BookingApiClient]. Writes always go
/// through FastAPI; this only ever reads.
class BookingsRepository {
  BookingsRepository(this._client, this._cache);

  final SupabaseClient _client;
  final OfflineCache _cache;

  Future<List<Booking>> fetchMyBookings(String customerId) async {
    final rows = await _cache.rows('my-bookings:$customerId', () => _client
        .from('bookings')
        .select('*, services(name), workers(name)')
        .eq('customer_id', customerId)
        .order('start_time', ascending: false));
    return rows.map(Booking.fromSupabaseRow).toList();
  }

  Future<List<Booking>> fetchBusinessBookings(String businessId) async {
    final rows = await _cache.rows('business-bookings:$businessId', () => _client
        .from('bookings')
        .select('*, services(name), workers(name), profiles(username)')
        .eq('business_id', businessId)
        .order('start_time'));
    return rows.map(Booking.fromSupabaseRow).toList();
  }

  Future<Booking?> fetchBooking(String bookingId) async {
    final row = await _cache.row('booking:$bookingId', () => _client.from('bookings').select().eq('id', bookingId).maybeSingle());
    if (row == null) return null;
    return Booking.fromSupabaseRow(row);
  }

  /// Every completed booking, oldest first, with whether it has a review —
  /// what the review pop-up on Home needs (see reviewPromptProvider).
  /// `reviews` is unique on `booking_id`, so PostgREST embeds it as a
  /// nullable object (`null` or a map), not a list; casting it as a List
  /// throws.
  Future<List<({Booking booking, bool reviewed})>> fetchCompletedBookings(String customerId) async {
    final rows = await _cache.rows('completed:$customerId', () => _client
        .from('bookings')
        .select('*, reviews(id)')
        .eq('customer_id', customerId)
        .eq('status', 'completed')
        .order('start_time'));
    return [for (final row in rows) (booking: Booking.fromSupabaseRow(row), reviewed: row['reviews'] != null)];
  }
}
