import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'l10n.dart';

import '../features/admin/presentation/admin_screen.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/domain/profile.dart';
import '../features/auth/presentation/account_settings_screen.dart';
import '../features/auth/presentation/edit_profile_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/get_the_app_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/auth/presentation/two_factor_screen.dart';
import '../features/business/application/business_controller.dart';
import '../features/business/presentation/edit_shop_page_screen.dart';
import '../features/business/presentation/business_edit_screen.dart';
import '../features/business/presentation/business_home_screen.dart';
import '../features/business/presentation/business_setup_screen.dart';
import '../features/business/presentation/services_screen.dart';
import '../features/business/presentation/bookings_screen.dart';
import '../features/business/presentation/finance_screen.dart';
import '../features/business/presentation/subscription_screen.dart';
import '../features/business/presentation/staff_screen.dart';
import '../features/business/presentation/worker_candidate_detail_screen.dart';
import '../features/business/presentation/worker_schedule_screen.dart';
import '../features/customer/presentation/shop_page.dart';
import '../features/customer/presentation/business_list_screen.dart';
import '../features/customer/presentation/booking_screen.dart';
import '../features/customer/presentation/customer_home_screen.dart';
import '../features/customer/presentation/my_bookings_screen.dart';
import '../features/customer/presentation/review_screen.dart';
import '../features/feed/presentation/create_post_screen.dart';
import '../features/feed/presentation/feed_screen.dart';
import '../features/feed/presentation/my_profile_screen.dart';
import '../features/feed/presentation/post_detail_screen.dart';
import '../features/feed/presentation/profile_screen.dart';
import '../features/feed/presentation/profile_search_screen.dart';
import '../features/designer/presentation/design_detail_screen.dart';
import '../features/designer/presentation/design_editor_screen.dart';
import '../features/designer/presentation/designer_gallery_screen.dart';
import '../features/messaging/presentation/conversation_screen.dart';
import '../features/messaging/presentation/conversations_screen.dart';
import '../features/rankings/presentation/rankings_screen.dart';
import '../features/rewards/presentation/reward_history_screen.dart';
import '../features/worker/domain/worker_profile.dart';
import '../features/worker/presentation/worker_profile_screen.dart';
import 'app_shell.dart';
import 'supabase_providers.dart';

const _authRoutes = {'/sign-in', '/sign-up', '/forgot-password'};
const _businessSetupRoute = '/business-setup';
const _twoFactorRoute = '/two-factor';
const _getTheAppRoute = '/get-the-app';

const _resetPasswordRoute = '/reset-password';

/// Pure routing decision, unit-testable without a live Supabase client.
String? resolveRedirect({
  required bool isAuthenticated,
  required Profile? profile,
  bool isProfileMissing = false,
  required bool isBusinessSetupComplete,
  required String location,
  bool passwordRecovery = false,
  bool needsSecondFactor = false,
  bool isWeb = false,
}) {
  // The password-reset email link signs the user into a temporary recovery
  // session — that counts as authenticated, but must not fall through to
  // normal home routing until they've actually set a new password.
  if (passwordRecovery) {
    return location == _resetPasswordRoute ? null : _resetPasswordRoute;
  }

  if (!isAuthenticated) {
    return _authRoutes.contains(location) ? null : '/sign-in';
  }

  if (profile == null) {
    // Signed in with no profile row — a first Google sign-in, which carries
    // no role/username to create one from. Send them to finish it even from
    // /sign-in, where the OAuth round trip lands them.
    if (isProfileMissing) return location == '/sign-up' ? null : '/sign-up';
    // Profile still loading, or its fetch failed: stay on the auth flow
    // rather than guess — sending an existing user to create a second
    // profile over a flaky connection would be worse than waiting.
    return _authRoutes.contains(location) ? null : '/sign-in';
  }

  // Before anything else an admin can reach — see TwoFactorScreen.
  if (needsSecondFactor) {
    return location == _twoFactorRoute ? null : _twoFactorRoute;
  }

  // The website is for shops (and the admin); customers use the app.
  if (isWeb && profile.role == AccountRole.customer && !profile.isAdmin) {
    return location == _getTheAppRoute ? null : _getTheAppRoute;
  }

  if (profile.role == AccountRole.business && !isBusinessSetupComplete) {
    return location == _businessSetupRoute ? null : _businessSetupRoute;
  }

  final home = profile.role == AccountRole.business ? '/business' : (isWeb ? '/admin' : '/customer');
  final onboardingRoutes = {..._authRoutes, _businessSetupRoute, _twoFactorRoute, _getTheAppRoute};
  return onboardingRoutes.contains(location) ? home : null;
}

class _RouterRefreshNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// The 3D haircut designer (Designs tab and its screens), paused for launch
/// in Oct 2026: off, no tab, link or route reaches it, but its code stays
/// so work can resume by turning this back on.
const designerEnabled = false;

List<NavigationDestination> _customerDestinations(AppLocalizations l10n) => [
      NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: l10n.navHome),
      NavigationDestination(
          icon: const Icon(Icons.storefront_outlined), selectedIcon: const Icon(Icons.storefront), label: l10n.navBrowse),
      NavigationDestination(icon: const Icon(Icons.photo_outlined), selectedIcon: const Icon(Icons.photo), label: l10n.navFeed),
      if (designerEnabled)
        NavigationDestination(
            icon: const Icon(Icons.content_cut_outlined), selectedIcon: const Icon(Icons.content_cut), label: l10n.navDesigns),
      NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: l10n.navProfile),
    ];

List<NavigationDestination> _businessDestinations(AppLocalizations l10n) => [
      NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: l10n.navHome),
      NavigationDestination(icon: const Icon(Icons.event_outlined), selectedIcon: const Icon(Icons.event), label: l10n.navBookings),
      NavigationDestination(icon: const Icon(Icons.photo_outlined), selectedIcon: const Icon(Icons.photo), label: l10n.navFeed),
      NavigationDestination(icon: const Icon(Icons.groups_outlined), selectedIcon: const Icon(Icons.groups), label: l10n.navStaff),
      NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: l10n.navProfile),
    ];

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshNotifier();
  ref.listen(authStateChangesProvider, (_, __) => refresh.ping());
  ref.listen(currentProfileProvider, (_, __) => refresh.ping());
  ref.listen(currentBusinessProvider, (_, __) => refresh.ping());
  ref.listen(passwordRecoveryProvider, (_, __) => refresh.ping());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/sign-in',
    refreshListenable: refresh,
    redirect: (context, state) {
      final isAuthenticated = ref.read(supabaseClientProvider).auth.currentUser != null;
      final profileState = ref.read(currentProfileProvider);
      final isBusinessSetupComplete = ref.read(currentBusinessProvider).value?.isSetupComplete ?? false;
      final auth = ref.read(supabaseClientProvider).auth;
      return resolveRedirect(
        isAuthenticated: isAuthenticated,
        profile: profileState.value,
        // Only a finished, successful fetch that found no row means "missing".
        isProfileMissing: profileState.hasValue &&
            !profileState.isLoading &&
            !profileState.hasError &&
            profileState.value == null,
        isBusinessSetupComplete: isBusinessSetupComplete,
        location: state.matchedLocation,
        passwordRecovery: ref.read(passwordRecoveryProvider),
        needsSecondFactor: profileState.value?.isAdmin == true &&
            auth.mfa.getAuthenticatorAssuranceLevel().currentLevel != AuthenticatorAssuranceLevels.aal2,
        isWeb: kIsWeb,
      );
    },
    routes: [
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => SignInScreen(initialMessage: state.extra as String?),
      ),
      GoRoute(path: '/sign-up', builder: (context, state) => const SignUpScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: _resetPasswordRoute, builder: (context, state) => const ResetPasswordScreen()),
      GoRoute(path: _twoFactorRoute, builder: (context, state) => const TwoFactorScreen()),
      GoRoute(path: _getTheAppRoute, builder: (context, state) => const GetTheAppScreen()),
      GoRoute(path: '/account-settings', builder: (context, state) => const AccountSettingsScreen()),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell, destinations: _customerDestinations(context.l10n)),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/customer', builder: (context, state) => const CustomerHomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/customer/businesses',
              builder: (context, state) => const BusinessListScreen(),
              routes: [
                GoRoute(
                  path: ':businessId',
                  builder: (context, state) =>
                      ShopPage(businessId: state.pathParameters['businessId']!),
                  routes: [
                    GoRoute(
                      path: 'book',
                      builder: (context, state) => BookingScreen(
                        businessId: state.pathParameters['businessId']!,
                        serviceId: state.uri.queryParameters['serviceId']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/feed', builder: (context, state) => const FeedScreen()),
          ]),
          if (designerEnabled)
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/designs',
                builder: (context, state) => const DesignerGalleryScreen(),
                routes: [
                  GoRoute(path: 'new', builder: (context, state) => const DesignEditorScreen()),
                  GoRoute(
                    path: ':designId/edit',
                    builder: (context, state) => DesignEditorScreen(designId: state.pathParameters['designId']!),
                  ),
                  GoRoute(
                    path: ':designId',
                    builder: (context, state) => DesignDetailScreen(designId: state.pathParameters['designId']!),
                  ),
                ],
              ),
            ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/customer/profile', builder: (context, state) => const MyProfileScreen()),
          ]),
        ],
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell, destinations: _businessDestinations(context.l10n)),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/business', builder: (context, state) => const BusinessHomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/business/bookings', builder: (context, state) => const BookingsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/business/feed', builder: (context, state) => const FeedScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/business/staff', builder: (context, state) => const StaffScreen()),
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
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/business/profile', builder: (context, state) => const MyProfileScreen()),
          ]),
        ],
      ),

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
      GoRoute(path: '/business/edit', builder: (context, state) => const BusinessEditScreen()),
      GoRoute(path: _businessSetupRoute, builder: (context, state) => const BusinessSetupScreen()),
      GoRoute(path: '/business/services', builder: (context, state) => const ServicesScreen()),
      GoRoute(path: '/business/shop/edit', builder: (context, state) => const EditShopPageScreen()),
      // Posts are shared by both roles, so they live outside either tab
      // shell: opened from the customer or the business feed (or a shop
      // page), they stack over whichever shell you're in. Nested under one
      // shell, they'd switch a business into the customer's tabs.
      GoRoute(path: '/posts/new', builder: (context, state) => const CreatePostScreen()),
      GoRoute(
        path: '/posts/:postId',
        builder: (context, state) => PostDetailScreen(postId: state.pathParameters['postId']!),
      ),
      GoRoute(path: '/business/finance', builder: (context, state) => const FinanceScreen()),
      GoRoute(path: '/business/subscription', builder: (context, state) => const SubscriptionScreen()),
      GoRoute(path: '/rankings', builder: (context, state) => const RankingsScreen()),
      GoRoute(path: '/rewards', builder: (context, state) => const RewardHistoryScreen()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),
      GoRoute(path: '/messages', builder: (context, state) => const ConversationsScreen()),
      GoRoute(
        path: '/messages/:conversationId',
        builder: (context, state) =>
            ConversationScreen(conversationId: state.pathParameters['conversationId']!),
      ),
      GoRoute(path: '/profile/edit', builder: (context, state) => const EditProfileScreen()),
      GoRoute(path: '/profile/search', builder: (context, state) => const ProfileSearchScreen()),
      GoRoute(
        path: '/profile/:profileId',
        builder: (context, state) => ProfileScreen(profileId: state.pathParameters['profileId']!),
      ),
    ],
  );
});
