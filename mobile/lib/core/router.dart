import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/domain/profile.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/business/application/business_controller.dart';
import '../features/business/presentation/business_home_screen.dart';
import '../features/business/presentation/business_setup_screen.dart';
import '../features/business/presentation/services_screen.dart';
import '../features/business/presentation/bookings_screen.dart';
import '../features/business/presentation/staff_screen.dart';
import '../features/customer/application/review_controller.dart';
import '../features/customer/presentation/business_detail_screen.dart';
import '../features/customer/presentation/business_list_screen.dart';
import '../features/customer/presentation/booking_screen.dart';
import '../features/customer/presentation/customer_home_screen.dart';
import '../features/customer/presentation/my_bookings_screen.dart';
import '../features/customer/presentation/review_screen.dart';
import '../features/worker/presentation/worker_profile_screen.dart';
import 'supabase_providers.dart';

const _authRoutes = {'/sign-in', '/sign-up'};
const _businessSetupRoute = '/business-setup';

bool _isReviewRoute(String location, String? bookingId) {
  return bookingId != null && location == '/customer/bookings/$bookingId/review';
}

/// Pure routing decision, unit-testable without a live Supabase client.
String? resolveRedirect({
  required bool isAuthenticated,
  required Profile? profile,
  required bool hasBusiness,
  required String? pendingReviewBookingId,
  required String location,
}) {
  if (!isAuthenticated) {
    return _authRoutes.contains(location) ? null : '/sign-in';
  }

  if (profile == null) {
    // Signed in (or mid email-confirmation) but no profile row yet — keep
    // them on the auth flow rather than bouncing to an empty home screen.
    return _authRoutes.contains(location) ? null : '/sign-up';
  }

  if (profile.role == AccountRole.business && !hasBusiness) {
    return location == _businessSetupRoute ? null : _businessSetupRoute;
  }

  // Re-checked on every navigation attempt (not just once on open) so the
  // customer genuinely can't do anything else until they've rated or
  // omitted every step — see review_screen.dart.
  if (profile.role == AccountRole.customer &&
      pendingReviewBookingId != null &&
      !_isReviewRoute(location, pendingReviewBookingId)) {
    return '/customer/bookings/$pendingReviewBookingId/review';
  }

  final home = profile.role == AccountRole.customer ? '/customer' : '/business';
  final onboardingRoutes = {..._authRoutes, _businessSetupRoute};
  return onboardingRoutes.contains(location) ? home : null;
}

class _RouterRefreshNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshNotifier();
  ref.listen(authStateChangesProvider, (_, __) => refresh.ping());
  ref.listen(currentProfileProvider, (_, __) => refresh.ping());
  ref.listen(currentBusinessProvider, (_, __) => refresh.ping());
  ref.listen(pendingReviewProvider, (_, __) => refresh.ping());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/sign-in',
    refreshListenable: refresh,
    redirect: (context, state) {
      final isAuthenticated = ref.read(supabaseClientProvider).auth.currentUser != null;
      final profile = ref.read(currentProfileProvider).value;
      final hasBusiness = ref.read(currentBusinessProvider).value != null;
      final pendingReviewBookingId = ref.read(pendingReviewProvider).value?.id;
      return resolveRedirect(
        isAuthenticated: isAuthenticated,
        profile: profile,
        hasBusiness: hasBusiness,
        pendingReviewBookingId: pendingReviewBookingId,
        location: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(path: '/sign-in', builder: (context, state) => const SignInScreen()),
      GoRoute(path: '/sign-up', builder: (context, state) => const SignUpScreen()),
      GoRoute(path: '/customer', builder: (context, state) => const CustomerHomeScreen()),
      GoRoute(
        path: '/customer/worker-profile',
        builder: (context, state) => const WorkerProfileScreen(),
      ),
      GoRoute(
        path: '/customer/my-bookings',
        builder: (context, state) => const MyBookingsScreen(),
      ),
      GoRoute(
        path: '/customer/bookings/:bookingId/review',
        builder: (context, state) => ReviewScreen(bookingId: state.pathParameters['bookingId']!),
      ),
      GoRoute(
        path: '/customer/businesses',
        builder: (context, state) => const BusinessListScreen(),
      ),
      GoRoute(
        path: '/customer/businesses/:businessId',
        builder: (context, state) =>
            BusinessDetailScreen(businessId: state.pathParameters['businessId']!),
      ),
      GoRoute(
        path: '/customer/businesses/:businessId/book',
        builder: (context, state) => BookingScreen(
          businessId: state.pathParameters['businessId']!,
          serviceId: state.uri.queryParameters['serviceId']!,
        ),
      ),
      GoRoute(path: '/business', builder: (context, state) => const BusinessHomeScreen()),
      GoRoute(path: _businessSetupRoute, builder: (context, state) => const BusinessSetupScreen()),
      GoRoute(path: '/business/services', builder: (context, state) => const ServicesScreen()),
      GoRoute(path: '/business/staff', builder: (context, state) => const StaffScreen()),
      GoRoute(path: '/business/bookings', builder: (context, state) => const BookingsScreen()),
    ],
  );
});
