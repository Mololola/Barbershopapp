import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/profile.dart';
import '../../customer/application/booking_controller.dart' show bookingsRepositoryProvider;
import '../../customer/domain/booking.dart';
import '../../worker/domain/worker_invitation.dart';
import '../../worker/domain/worker_profile.dart';
import '../data/billing_api_client.dart';
import '../data/business_repository.dart';
import '../domain/business.dart';
import '../domain/business_subscription.dart';

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return BusinessRepository(ref.watch(supabaseClientProvider));
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
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return null;
  return ref.watch(businessRepositoryProvider).fetchSubscription(business.id);
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

final sentInvitationsProvider = FutureProvider<List<WorkerInvitation>>((ref) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return [];
  return ref.watch(businessRepositoryProvider).fetchSentInvitations(business.id);
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
}

final serviceControllerProvider = AsyncNotifierProvider<ServiceController, void>(ServiceController.new);

class ServiceController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addService({
    required String name,
    required int priceCents,
    required int durationMinutes,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final business = await ref.read(currentBusinessProvider.future);
      if (business == null) throw StateError('No business set up yet.');
      await ref.read(businessRepositoryProvider).addService(
            Service(
              businessId: business.id,
              name: name,
              priceCents: priceCents,
              durationMinutes: durationMinutes,
            ),
          );
      ref.invalidate(servicesProvider);
    });
  }

  Future<void> deleteService(String serviceId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(businessRepositoryProvider).deleteService(serviceId);
      ref.invalidate(servicesProvider);
    });
  }
}

final costItemControllerProvider =
    AsyncNotifierProvider<CostItemController, void>(CostItemController.new);

class CostItemController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addCostItem({required String label, required int amountCents}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final business = await ref.read(currentBusinessProvider.future);
      if (business == null) throw StateError('No business set up yet.');
      await ref.read(businessRepositoryProvider).addCostItem(business.id, label, amountCents);
      ref.invalidate(costItemsProvider);
    });
  }

  Future<void> deleteCostItem(String costItemId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(businessRepositoryProvider).deleteCostItem(costItemId);
      ref.invalidate(costItemsProvider);
    });
  }
}

/// autoDispose — a business browsing the marketplace needs whoever is
/// looking for work *right now*, not whatever was cached from the last
/// time any business viewed this screen in the current app session.
final workersLookingForWorkProvider = FutureProvider.autoDispose<List<WorkerSearchResult>>((ref) {
  return ref.watch(businessRepositoryProvider).fetchWorkersLookingForWork();
});

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

  Future<void> deleteWorker(String workerId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(businessRepositoryProvider).deleteWorker(workerId);
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

  Future<bool> save({File? logoImage, required List<BusinessLocation> locations}) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      final business = await ref.read(currentBusinessProvider.future);
      if (business == null) throw StateError('No business set up yet.');

      if (logoImage != null) {
        // Same uploaded image becomes both the owner's personal avatar
        // (shown on the feed/profile-search) and the business's public logo.
        final url = await ref.read(profileRepositoryProvider).uploadAvatarImage(business.ownerId, logoImage);
        await ref.read(profileRepositoryProvider).updateAvatarUrl(business.ownerId, url);
        await ref.read(businessRepositoryProvider).updateLogoUrl(business.id, url);
      }
      await ref.read(businessRepositoryProvider).updateLocations(business.id, locations);

      ref.invalidate(currentBusinessProvider);
      ref.invalidate(locationsProvider);
      ref.invalidate(currentProfileProvider);
      await ref.read(currentBusinessProvider.future);
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
