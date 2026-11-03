import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/offline_cache.dart';
import '../../../core/api_client.dart';
import '../../../core/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/profile.dart';
import '../../customer/application/booking_controller.dart' show bookingsRepositoryProvider;
import '../../customer/application/browse_controller.dart';
import '../../customer/domain/booking.dart';
import '../../worker/domain/worker_invitation.dart';
import '../../worker/domain/worker_leave_request.dart';
import '../../worker/domain/worker_profile.dart';
import '../data/billing_api_client.dart';
import '../data/business_repository.dart';
import '../domain/business.dart';
import '../domain/finance_overview.dart';
import '../domain/business_subscription.dart';

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return BusinessRepository(ref.watch(supabaseClientProvider), ref.watch(offlineCacheProvider));
});

final billingApiClientProvider = Provider<BillingApiClient>((ref) {
  return BillingApiClient(ref.watch(apiClientProvider));
});

final currentBusinessProvider = FutureProvider<Business?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null || profile.role != AccountRole.business) return null;
  return ref.watch(businessRepositoryProvider).fetchOwnBusiness(profile.id);
});

/// autoDispose — subscription status can flip via a Stripe webhook at any
/// time, independent of anything the app itself does; re-fetch whenever the
/// home screen is opened, same reasoning as rankings/marketplace elsewhere.
final businessSubscriptionProvider = FutureProvider.autoDispose<BusinessSubscription?>((ref) async {
  // Checkout and the billing portal run in the browser; when the owner comes
  // back, the webhook has usually updated the subscription already.
  final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(lifecycle.dispose);
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return null;
  return ref.watch(businessRepositoryProvider).fetchSubscription(business.id);
});

final financePremiumSubscriptionProvider = FutureProvider.autoDispose<FinancePremiumSubscription?>((ref) async {
  final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(lifecycle.dispose);
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return null;
  return ref.watch(businessRepositoryProvider).fetchFinancePremiumSubscription(business.id);
});

/// One month of the finance tool, keyed by the month's first day.
/// autoDispose — premium status can flip via a Stripe webhook at any time,
/// and revenue moves with every completed booking.
final financeOverviewProvider = FutureProvider.autoDispose.family<FinanceOverview, DateTime>((ref, month) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) throw StateError('No business set up yet.');
  return ref.watch(billingApiClientProvider).fetchFinanceOverview(business.id, month);
});

final billingActionControllerProvider =
    AsyncNotifierProvider<BillingActionController, void>(BillingActionController.new);

class BillingActionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String> startCheckout() async {
    final business = await ref.read(currentBusinessProvider.future);
    if (business == null) throw StateError('No business set up yet.');
    return ref.read(billingApiClientProvider).createCheckoutSession(business.id);
  }

  Future<String> openPortal() async {
    final business = await ref.read(currentBusinessProvider.future);
    if (business == null) throw StateError('No business set up yet.');
    return ref.read(billingApiClientProvider).createPortalSession(business.id);
  }

  /// Cancels at the end of the trial or paid month, never immediately.
  Future<void> cancelSubscription() => _changeSubscription((api, id) => api.cancelSubscription(id));

  Future<void> resumeSubscription() => _changeSubscription((api, id) => api.resumeSubscription(id));

  /// Like [cancelSubscription], for the Finance Premium add-on.
  Future<void> cancelFinancePremium() => _changeSubscription((api, id) => api.cancelFinancePremium(id));

  Future<void> resumeFinancePremium() => _changeSubscription((api, id) => api.resumeFinancePremium(id));

  Future<void> _changeSubscription(Future<void> Function(BillingApiClient api, String businessId) change) async {
    final business = await ref.read(currentBusinessProvider.future);
    if (business == null) throw StateError('No business set up yet.');
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await change(ref.read(billingApiClientProvider), business.id);
      ref.invalidate(businessSubscriptionProvider);
      ref.invalidate(financePremiumSubscriptionProvider);
    });
  }

  Future<void> startFinanceTrial() async {
    final business = await ref.read(currentBusinessProvider.future);
    if (business == null) throw StateError('No business set up yet.');
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(billingApiClientProvider).startFinanceTrial(business.id);
      ref.invalidate(financeOverviewProvider);
    });
  }

  Future<String> startFinanceCheckout() async {
    final business = await ref.read(currentBusinessProvider.future);
    if (business == null) throw StateError('No business set up yet.');
    return ref.read(billingApiClientProvider).createFinanceAccessCheckout(business.id);
  }
}

final locationsProvider = FutureProvider<List<BusinessLocation>>((ref) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return [];
  return ref.watch(businessRepositoryProvider).fetchLocations(business.id);
});

final openingHoursProvider = FutureProvider<List<OpeningHours>>((ref) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return [];
  return ref.watch(businessRepositoryProvider).fetchOpeningHours(business.id);
});

final servicesProvider = FutureProvider<List<Service>>((ref) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return [];
  return ref.watch(businessRepositoryProvider).fetchServices(business.id);
});

final costItemsProvider = FutureProvider<List<CostItem>>((ref) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return [];
  return ref.watch(businessRepositoryProvider).fetchCostItems(business.id);
});

final workersProvider = FutureProvider<List<Worker>>((ref) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return [];
  return ref.watch(businessRepositoryProvider).fetchWorkers(business.id);
});

final workerScheduleProvider = FutureProvider.family<List<OpeningHours>, String>((ref, workerId) {
  return ref.watch(businessRepositoryProvider).fetchWorkerSchedule(workerId);
});

final businessBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return [];
  return ref.watch(bookingsRepositoryProvider).fetchBusinessBookings(business.id);
});

/// See AutoCompletedCheckCard.
final autoCompletedToCheckProvider = FutureProvider.autoDispose<List<Booking>>((ref) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return [];
  return ref.watch(bookingsRepositoryProvider).fetchAutoCompletedToCheck(business.id, DateTime.now());
});

final sentInvitationsProvider = FutureProvider<List<WorkerInvitation>>((ref) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return [];
  return ref.watch(businessRepositoryProvider).fetchSentInvitations(business.id);
});

/// autoDispose — a worker could ask to leave at any time, independent of
/// anything the app itself does; re-fetch whenever the screen reopens, same
/// reasoning as the marketplace/rankings.
final pendingLeaveRequestsProvider = FutureProvider.autoDispose<List<WorkerLeaveRequest>>((ref) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return [];
  return ref.watch(businessRepositoryProvider).fetchPendingLeaveRequests(business.id);
});

final leaveRequestControllerProvider =
    AsyncNotifierProvider<LeaveRequestController, void>(LeaveRequestController.new);

class LeaveRequestController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> acknowledge(WorkerLeaveRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(businessRepositoryProvider).acknowledgeLeaveRequest(request);
      ref.invalidate(pendingLeaveRequestsProvider);
      ref.invalidate(workersProvider);
    });
  }

  Future<void> reject(WorkerLeaveRequest request) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(businessRepositoryProvider).rejectLeaveRequest(request);
      ref.invalidate(pendingLeaveRequestsProvider);
    });
  }
}

/// The business name given at sign-up — kept as auth user metadata since
/// the business row can't exist before a session does. Pre-fills the setup
/// wizard's name field.
final signUpBusinessNameProvider = Provider<String?>((ref) {
  return ref.watch(supabaseClientProvider).auth.currentUser?.userMetadata?['business_name'] as String?;
});

final businessSetupControllerProvider =
    AsyncNotifierProvider<BusinessSetupController, void>(BusinessSetupController.new);

class BusinessSetupController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> createBusiness({
    required String name,
    String? phone,
    required String currency,
    required List<BusinessLocation> locations,
    required List<OpeningHours> openingHours,
    String? referredByCode,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final profile = await ref.read(currentProfileProvider.future);
      if (profile == null) throw StateError('No signed-in profile.');
      await ref.read(businessRepositoryProvider).createBusiness(
            ownerId: profile.id,
            name: name,
            phone: phone,
            currency: currency,
            locations: locations,
            openingHours: openingHours,
            referredByCode: referredByCode,
          );
      ref.invalidate(currentBusinessProvider);
    });
  }

  Future<void> completeSetup() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final business = await ref.read(currentBusinessProvider.future);
      if (business == null) throw StateError('No business set up yet.');
      await ref.read(businessRepositoryProvider).markSetupComplete(business.id);
      ref.invalidate(currentBusinessProvider);
    });
  }
}

final serviceControllerProvider = AsyncNotifierProvider<ServiceController, void>(ServiceController.new);

class ServiceController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// [isFirst]: it becomes the basic cut (services_default_basic_cut).
  Future<void> addService({
    required String name,
    required int priceCents,
    required int durationMinutes,
    bool isFirst = false,
  }) =>
      _run((businessId) async {
        await ref.read(businessRepositoryProvider).addService(
              Service(businessId: businessId, name: name, priceCents: priceCents, durationMinutes: durationMinutes),
            );
        if (isFirst) await _syncSubscriptionPrice(businessId);
      });

  Future<void> updateService(Service service) => _run((businessId) async {
        await ref.read(businessRepositoryProvider).updateService(service);
        if (service.isBasicCut) await _syncSubscriptionPrice(businessId);
      });

  Future<void> removeService(String serviceId) =>
      _run((_) => ref.read(businessRepositoryProvider).removeService(serviceId));

  Future<void> makeBasicCut(String serviceId) => _run((businessId) async {
        await ref.read(billingApiClientProvider).setBasicCut(businessId, serviceId);
        ref.invalidate(businessSubscriptionProvider);
      });

  // Services are written straight to Supabase, so the backend is asked to
  // move the subscription to the basic cut's new price now.
  Future<void> _syncSubscriptionPrice(String businessId) async {
    await ref.read(billingApiClientProvider).syncSubscriptionPrice(businessId);
    ref.invalidate(businessSubscriptionProvider);
  }

  Future<void> _run(Future<void> Function(String businessId) action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final business = await ref.read(currentBusinessProvider.future);
      if (business == null) throw StateError('No business set up yet.');
      await action(business.id);
      ref.invalidate(servicesProvider);
    });
  }
}

final financeControllerProvider = AsyncNotifierProvider<FinanceController, void>(FinanceController.new);

/// Costs and other income. Every change refreshes the finance figures,
/// which the backend recomputes from them.
class FinanceController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> _run(Future<void> Function(String businessId) action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final business = await ref.read(currentBusinessProvider.future);
      if (business == null) throw StateError('No business set up yet.');
      await action(business.id);
      ref.invalidate(costItemsProvider);
      ref.invalidate(financeOverviewProvider);
    });
  }

  Future<void> addCost({
    required String label,
    required int amountCents,
    required CostKind kind,
    required DateTime month,
  }) {
    return _run(
      (businessId) => ref.read(businessRepositoryProvider).addCostItem(
            CostItem(businessId: businessId, label: label, amountCents: amountCents, kind: kind, startsOn: month),
          ),
    );
  }

  Future<void> stopCostAfter(String costItemId, DateTime lastMonth) =>
      _run((_) => ref.read(businessRepositoryProvider).endCostItem(costItemId, lastMonth));

  Future<void> deleteCost(String costItemId) =>
      _run((_) => ref.read(businessRepositoryProvider).deleteCostItem(costItemId));

  Future<void> setOtherIncome(DateTime month, int amountCents) =>
      _run((businessId) => ref.read(businessRepositoryProvider).setOtherIncome(businessId, month, amountCents));
}

/// The Available Workers marketplace list — a real paginated notifier, not
/// a single FutureProvider, since this list can run into the thousands
/// (see fetchWorkersLookingForWork). autoDispose for the same reason as the
/// old provider: whoever's looking for work *right now*, not a stale
/// session cache.
class MarketplaceFilters {
  const MarketplaceFilters({
    this.nameQuery,
    this.minYearsExperience,
    this.minShopsWorked,
    this.minAverageRating,
  });

  final String? nameQuery;
  final int? minYearsExperience;
  final int? minShopsWorked;
  final double? minAverageRating;
}

final marketplaceControllerProvider =
    AsyncNotifierProvider.autoDispose<MarketplaceController, List<WorkerSearchResult>>(
        MarketplaceController.new);

class MarketplaceController extends AsyncNotifier<List<WorkerSearchResult>> {
  static const _pageSize = 20;

  MarketplaceFilters _filters = const MarketplaceFilters();
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  @override
  Future<List<WorkerSearchResult>> build() {
    return _fetchPage(offset: 0);
  }

  // Sets _hasMore itself so every caller (the initial build(), a filter
  // change, a scroll-triggered loadMore()) gets it right — a first page
  // shorter than a full page already means there's nothing more to load,
  // not just something loadMore() discovers on its own next call.
  Future<List<WorkerSearchResult>> _fetchPage({required int offset}) async {
    final page = await ref.read(businessRepositoryProvider).fetchWorkersLookingForWork(
          nameQuery: _filters.nameQuery,
          minYearsExperience: _filters.minYearsExperience,
          minShopsWorked: _filters.minShopsWorked,
          minAverageRating: _filters.minAverageRating,
          offset: offset,
          limit: _pageSize,
        );
    _hasMore = page.length == _pageSize;
    return page;
  }

  Future<void> applyFilters(MarketplaceFilters filters) async {
    _filters = filters;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchPage(offset: 0));
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    final current = state.value ?? [];
    _isLoadingMore = true;
    try {
      final next = await _fetchPage(offset: current.length);
      state = AsyncData([...current, ...next]);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    } finally {
      _isLoadingMore = false;
    }
  }
}

final workerControllerProvider = AsyncNotifierProvider<WorkerController, void>(WorkerController.new);

class WorkerController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addWorker(String name) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final business = await ref.read(currentBusinessProvider.future);
      if (business == null) throw StateError('No business set up yet.');
      await ref.read(businessRepositoryProvider).addWorker(
            Worker(businessId: business.id, businessName: business.name, name: name),
          );
      ref.invalidate(workersProvider);
    });
  }

  Future<void> removeWorker(String workerId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(businessRepositoryProvider).removeWorker(workerId);
      ref.invalidate(workersProvider);
    });
  }

  Future<List<WorkerSearchResult>> findWorkersByName({
    required String firstName,
    required String lastName,
    String? secondLastName,
  }) {
    return ref.read(businessRepositoryProvider).findWorkersByName(
          firstName: firstName,
          lastName: lastName,
          secondLastName: secondLastName,
        );
  }

  Future<void> inviteWorker(String workerProfileId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final business = await ref.read(currentBusinessProvider.future);
      if (business == null) throw StateError('No business set up yet.');
      // Friendly early answer; the DB trigger enforces it regardless.
      final staff = await ref.read(workersProvider.future);
      if (staff.any((worker) => worker.profileId == workerProfileId)) {
        throw const StaffChangeBlockedException('BB002', "They're already on your staff.");
      }
      await ref.read(businessRepositoryProvider).createInvitation(
            businessId: business.id,
            businessName: business.name,
            workerProfileId: workerProfileId,
          );
      ref.invalidate(sentInvitationsProvider);
    });
  }
}

final businessEditControllerProvider =
    AsyncNotifierProvider<BusinessEditController, void>(BusinessEditController.new);

class BusinessEditController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> save({required List<BusinessLocation> locations, required List<OpeningHours> hours}) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      final business = await ref.read(currentBusinessProvider.future);
      if (business == null) throw StateError('No business set up yet.');

      await ref.read(businessRepositoryProvider).updateLocations(business.id, locations);
      await ref.read(businessRepositoryProvider).updateOpeningHours(business.id, hours);

      ref.invalidate(currentBusinessProvider);
      ref.invalidate(locationsProvider);
      ref.invalidate(openingHoursProvider);
      ref.invalidate(businessLocationsProvider(business.id));
      ref.invalidate(businessOpeningHoursProvider(business.id));
      await ref.read(currentBusinessProvider.future);
      success = true;
    });
    return success;
  }
}

final shopBrandingControllerProvider =
    AsyncNotifierProvider<ShopBrandingController, void>(ShopBrandingController.new);

class ShopBrandingController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Only what changed is uploaded/written; null means "keep as is".
  Future<bool> save({XFile? logoImage, XFile? coverImage, String? brandColor}) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      final business = await ref.read(currentBusinessProvider.future);
      if (business == null) throw StateError('No business set up yet.');
      final profiles = ref.read(profileRepositoryProvider);

      String? logoUrl;
      if (logoImage != null) {
        // The logo doubles as the owner's avatar, shown next to their posts.
        logoUrl = await profiles.uploadAvatarImage(business.ownerId, logoImage);
        await profiles.updateAvatarUrl(business.ownerId, logoUrl);
      }
      final coverUrl = coverImage == null
          ? null
          : await profiles.uploadAvatarImage(business.ownerId, coverImage, fileName: 'cover');
      await ref
          .read(businessRepositoryProvider)
          .updateBranding(business.id, logoUrl: logoUrl, coverUrl: coverUrl, brandColor: brandColor);

      ref.invalidate(currentBusinessProvider);
      ref.invalidate(businessProvider(business.id));
      ref.invalidate(currentProfileProvider);
      success = true;
    });
    return success;
  }
}

final workerScheduleControllerProvider =
    AsyncNotifierProvider<WorkerScheduleController, void>(WorkerScheduleController.new);

class WorkerScheduleController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> save(String workerId, List<OpeningHours> hours) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await ref.read(businessRepositoryProvider).updateWorkerSchedule(workerId, hours);
      ref.invalidate(workerScheduleProvider(workerId));
      await ref.read(workerScheduleProvider(workerId).future);
      success = true;
    });
    return success;
  }
}
