import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/booking_api_client.dart';
import '../data/bookings_repository.dart';
import '../domain/booking.dart';

final bookingApiClientProvider = Provider<BookingApiClient>((ref) {
  return BookingApiClient(ref.watch(apiClientProvider));
});

final bookingsRepositoryProvider = Provider<BookingsRepository>((ref) {
  return BookingsRepository(ref.watch(supabaseClientProvider));
});

typedef AvailabilityQuery = ({String businessId, String workerId, String serviceId, DateTime date});

final availabilityProvider = FutureProvider.family<List<DateTime>, AvailabilityQuery>((ref, query) {
  return ref.watch(bookingApiClientProvider).fetchAvailability(
        businessId: query.businessId,
        workerId: query.workerId,
        serviceId: query.serviceId,
        date: query.date,
      );
});

final myBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.watch(bookingsRepositoryProvider).fetchMyBookings(profile.id);
});

final bookingProvider = FutureProvider.family<Booking?, String>((ref, bookingId) {
  return ref.watch(bookingsRepositoryProvider).fetchBooking(bookingId);
});

final bookingActionControllerProvider =
    AsyncNotifierProvider<BookingActionController, void>(BookingActionController.new);

class BookingActionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns the created booking, or null if it failed (state carries the error).
  Future<Booking?> createBooking({
    required String businessId,
    required String workerId,
    required String serviceId,
    required DateTime startTime,
  }) async {
    state = const AsyncLoading();
    Booking? created;
    state = await AsyncValue.guard(() async {
      created = await ref.read(bookingApiClientProvider).createBooking(
            businessId: businessId,
            workerId: workerId,
            serviceId: serviceId,
            startTime: startTime,
          );
      ref.invalidate(myBookingsProvider);
    });
    return created;
  }

  Future<void> cancelBooking(String bookingId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(bookingApiClientProvider).cancelBooking(bookingId);
      ref.invalidate(myBookingsProvider);
    });
  }

  Future<void> completeBooking(String bookingId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(bookingApiClientProvider).completeBooking(bookingId);
    });
  }
}
