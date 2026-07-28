import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_providers.dart';
import '../../auth/domain/profile.dart';
import '../../customer/domain/review.dart';
import '../data/admin_repository.dart';

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
}
