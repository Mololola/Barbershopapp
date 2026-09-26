import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/supabase_providers.dart';
import '../../auth/domain/profile.dart';
import '../../customer/domain/review.dart';
import '../../rewards/domain/payout_request.dart';
import '../data/admin_repository.dart';
import '../domain/admin_business_summary.dart';
import '../domain/admin_metrics.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(supabaseClientProvider));
});

// autoDispose — a stale cached search result would show the customer's
// is_quality_reviewer flag from before an admin's own toggle, since nothing
// here knows to invalidate it when the search results leave the screen and
// come back. Dropping the cache on unmount forces a fresh read every time.
final customerSearchProvider = FutureProvider.autoDispose.family<List<Profile>, String>((ref, query) {
  return ref.watch(adminRepositoryProvider).searchCustomers(query);
});

final customerReviewsProvider = FutureProvider.autoDispose.family<List<Review>, String>((ref, customerId) {
  return ref.watch(adminRepositoryProvider).fetchReviewsByCustomer(customerId);
});

/// autoDispose — a fresh snapshot every time the Overview tab opens.
final adminMetricsProvider = FutureProvider.autoDispose<AdminMetrics>((ref) async {
  final json = await ref.watch(apiClientProvider).get('/admin/metrics') as Map<String, dynamic>;
  return AdminMetrics.fromJson(json);
});

final adminBusinessesProvider = FutureProvider.autoDispose<List<AdminBusinessSummary>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchBusinesses();
});

final adminPayoutRequestsProvider = FutureProvider.autoDispose<List<PayoutRequest>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchAllPayoutRequests();
});

final adminActionControllerProvider =
    AsyncNotifierProvider<AdminActionController, void>(AdminActionController.new);

class AdminActionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> setQualityReviewer(String customerId, bool value) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(adminRepositoryProvider).setQualityReviewer(customerId, value);
      success = true;
    });
    return success;
  }

  Future<bool> grantTrial(String businessId) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(adminRepositoryProvider).grantTrial(businessId);
      ref.invalidate(adminBusinessesProvider);
      success = true;
    });
    return success;
  }

  Future<bool> resolvePayoutRequest({
    required String requestId,
    required PayoutRequestStatus status,
    String? adminNote,
  }) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref
          .read(adminRepositoryProvider)
          .resolvePayoutRequest(requestId: requestId, status: status, adminNote: adminNote);
      ref.invalidate(adminPayoutRequestsProvider);
      success = true;
    });
    return success;
  }
}
