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
}
