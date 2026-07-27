import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../business/domain/business.dart';
import '../data/worker_repository.dart';
import '../domain/worker_invitation.dart';
import '../domain/worker_profile.dart';

final workerRepositoryProvider = Provider<WorkerRepository>((ref) {
  return WorkerRepository(ref.watch(supabaseClientProvider));
});

final currentWorkerProfileProvider = FutureProvider<WorkerProfile?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return null;
  return ref.watch(workerRepositoryProvider).fetchOwnWorkerProfile(profile.id);
});

final receivedInvitationsProvider = FutureProvider<List<WorkerInvitation>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.watch(workerRepositoryProvider).fetchReceivedInvitations(profile.id);
});

final currentJobProvider = FutureProvider<Worker?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return null;
  return ref.watch(workerRepositoryProvider).fetchCurrentJob(profile.id);
});

/// Used by the public profile screen to show any given profile's worker
/// status, not just the signed-in user's own.
final workerProfileByIdProvider = FutureProvider.family<WorkerProfile?, String>((ref, profileId) {
  return ref.watch(workerRepositoryProvider).fetchOwnWorkerProfile(profileId);
});

final workerProfileControllerProvider =
    AsyncNotifierProvider<WorkerProfileController, void>(WorkerProfileController.new);

class WorkerProfileController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> save({
    required String legalFirstName,
    required String legalLastName,
    String? legalSecondLastName,
    required String bio,
    required String city,
    required bool isLookingForWork,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final profile = await ref.read(currentProfileProvider.future);
      if (profile == null) throw StateError('No signed-in profile.');
      await ref.read(workerRepositoryProvider).upsertWorkerProfile(
            WorkerProfile(
              profileId: profile.id,
              legalFirstName: legalFirstName,
              legalLastName: legalLastName,
              legalSecondLastName: legalSecondLastName,
              bio: bio,
              city: city,
              isLookingForWork: isLookingForWork,
            ),
          );
      ref.invalidate(currentWorkerProfileProvider);
    });
  }
}

final invitationControllerProvider =
    AsyncNotifierProvider<InvitationController, void>(InvitationController.new);

class InvitationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> accept(WorkerInvitation invitation) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final workerProfile = await ref.read(currentWorkerProfileProvider.future);
      if (workerProfile == null) throw StateError('No worker profile set up.');
      await ref
          .read(workerRepositoryProvider)
          .acceptInvitation(invitation, workerProfile.legalFullName);
      ref.invalidate(receivedInvitationsProvider);
      ref.invalidate(currentWorkerProfileProvider);
      ref.invalidate(currentJobProvider);
    });
  }

  Future<void> decline(String invitationId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(workerRepositoryProvider).declineInvitation(invitationId);
      ref.invalidate(receivedInvitationsProvider);
    });
  }
}

final jobControllerProvider = AsyncNotifierProvider<JobController, void>(JobController.new);

class JobController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> leave(String workerId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(workerRepositoryProvider).leaveCurrentJob(workerId);
      ref.invalidate(currentJobProvider);
    });
  }
}
