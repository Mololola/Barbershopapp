import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline_cache.dart';
import '../../../core/supabase_providers.dart';
import '../../business/domain/business.dart';
import '../data/browse_repository.dart';
import '../domain/public_business.dart';
import '../domain/shop_review.dart';

final browseRepositoryProvider = Provider<BrowseRepository>((ref) {
  return BrowseRepository(ref.watch(supabaseClientProvider), ref.watch(offlineCacheProvider));
});

final businessesProvider = FutureProvider<List<PublicBusiness>>((ref) {
  return ref.watch(browseRepositoryProvider).fetchBusinesses();
});

final businessProvider = FutureProvider.family<PublicBusiness?, String>((ref, businessId) {
  return ref.watch(browseRepositoryProvider).fetchBusiness(businessId);
});

final businessLocationsProvider = FutureProvider.family<List<BusinessLocation>, String>((ref, businessId) {
  return ref.watch(browseRepositoryProvider).fetchLocations(businessId);
});

final businessOpeningHoursProvider = FutureProvider.family<List<OpeningHours>, String>((ref, businessId) {
  return ref.watch(browseRepositoryProvider).fetchOpeningHours(businessId);
});

final businessServicesProvider = FutureProvider.family<List<Service>, String>((ref, businessId) {
  return ref.watch(browseRepositoryProvider).fetchServices(businessId);
});

final businessWorkersProvider = FutureProvider.family<List<Worker>, String>((ref, businessId) {
  return ref.watch(browseRepositoryProvider).fetchWorkers(businessId);
});

final businessReviewsProvider = FutureProvider.family<List<ShopReview>, String>((ref, businessId) {
  return ref.watch(browseRepositoryProvider).fetchRecentReviews(businessId);
});

final businessIdByOwnerProvider = FutureProvider.family<String?, String>((ref, ownerId) {
  return ref.watch(browseRepositoryProvider).fetchBusinessIdByOwner(ownerId);
});
