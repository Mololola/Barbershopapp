import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/presentation/admin_screen.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/domain/profile.dart';
import '../features/auth/presentation/edit_profile_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/business/application/business_controller.dart';
import '../features/business/presentation/business_edit_screen.dart';
import '../features/business/presentation/business_home_screen.dart';
import '../features/business/presentation/business_setup_screen.dart';
import '../features/business/presentation/services_screen.dart';
import '../features/business/presentation/bookings_screen.dart';
import '../features/business/presentation/staff_screen.dart';
import '../features/business/presentation/worker_candidate_detail_screen.dart';
import '../features/business/presentation/worker_schedule_screen.dart';
import '../features/customer/application/review_controller.dart';
import '../features/customer/presentation/business_detail_screen.dart';
import '../features/customer/presentation/business_list_screen.dart';
import '../features/customer/presentation/booking_screen.dart';
import '../features/customer/presentation/customer_home_screen.dart';
import '../features/customer/presentation/my_bookings_screen.dart';
import '../features/customer/presentation/review_screen.dart';
import '../features/feed/presentation/create_post_screen.dart';
import '../features/feed/presentation/feed_screen.dart';
import '../features/feed/presentation/post_detail_screen.dart';
import '../features/feed/presentation/profile_screen.dart';
import '../features/feed/presentation/profile_search_screen.dart';
import '../features/rankings/presentation/rankings_screen.dart';
import '../features/rewards/presentation/reward_history_screen.dart';
import '../features/worker/domain/worker_profile.dart';
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
      GoRoute(path: '/business/edit', builder: (context, state) => const BusinessEditScreen()),
      GoRoute(path: _businessSetupRoute, builder: (context, state) => const BusinessSetupScreen()),
      GoRoute(path: '/business/services', builder: (context, state) => const ServicesScreen()),
      GoRoute(path: '/business/staff', builder: (context, state) => const StaffScreen()),
      GoRoute(path: '/business/bookings', builder: (context, state) => const BookingsScreen()),
      GoRoute(
        path: '/business/staff/:workerId/schedule',
        builder: (context, state) => WorkerScheduleScreen(
          workerId: state.pathParameters['workerId']!,
          workerName: state.extra as String,
        ),
      ),
      GoRoute(
        path: '/business/browse-workers/:profileId',
        builder: (context, state) => WorkerCandidateDetailScreen(candidate: state.extra as WorkerSearchResult),
      ),
      GoRoute(path: '/feed', builder: (context, state) => const FeedScreen()),
      GoRoute(path: '/feed/new', builder: (context, state) => const CreatePostScreen()),
      GoRoute(
        path: '/feed/:postId',
        builder: (context, state) => PostDetailScreen(postId: state.pathParameters['postId']!),
      ),
      GoRoute(path: '/rankings', builder: (context, state) => const RankingsScreen()),
      GoRoute(path: '/rewards', builder: (context, state) => const RewardHistoryScreen()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),
      GoRoute(path: '/profile/edit', builder: (context, state) => const EditProfileScreen()),
      GoRoute(path: '/profile/search', builder: (context, state) => const ProfileSearchScreen()),
      GoRoute(
        path: '/profile/:profileId',
        builder: (context, state) => ProfileScreen(profileId: state.pathParameters['profileId']!),
      ),
    ],
  );
});
