import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/profile.dart';
import '../../worker/domain/worker_invitation.dart';
import '../../worker/domain/worker_profile.dart';
import '../data/business_repository.dart';
import '../domain/business.dart';

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return BusinessRepository(ref.watch(supabaseClientProvider));
});

final currentBusinessProvider = FutureProvider<Business?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null || profile.role != AccountRole.business) return null;
  return ref.watch(businessRepositoryProvider).fetchOwnBusiness(profile.id);
});

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

final workersProvider = FutureProvider<List<Worker>>((ref) async {
  final business = await ref.watch(currentBusinessProvider.future);
  if (business == null) return [];
  return ref.watch(businessRepositoryProvider).fetchWorkers(business.id);
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
