import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline_cache.dart';
import '../../../core/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../business/domain/business.dart';
import '../../messaging/application/messaging_controller.dart';
import '../../messaging/domain/conversation.dart';
import '../data/worker_repository.dart';
import '../domain/worker_invitation.dart';
import '../domain/worker_leave_request.dart';
import '../domain/worker_profile.dart';

final workerRepositoryProvider = Provider<WorkerRepository>((ref) {
  return WorkerRepository(ref.watch(supabaseClientProvider), ref.watch(offlineCacheProvider));
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

/// The most recent leave request against the current job, if any — drives
/// the "request pending, awaiting the shop" state on worker_profile_screen.
final pendingLeaveRequestProvider = FutureProvider<WorkerLeaveRequest?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return null;
  final requests = await ref.watch(workerRepositoryProvider).fetchOwnLeaveRequests(profile.id);
  return requests.where((r) => r.status == LeaveRequestStatus.pending).firstOrNull;
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
    int? yearsExperience,
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
              yearsExperience: yearsExperience,
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

  /// Files a pending leave request and drops a message into the business's
  /// DM inbox so it's somewhere they'll actually see it — the worker's
  /// `workers` row stays active until the business acknowledges (see
  /// acknowledgeLeaveRequest), so this alone doesn't free them up to accept
  /// another job or reappear in a marketplace search.
  Future<void> requestLeave(Worker job) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final profile = await ref.read(currentProfileProvider.future);
      if (profile == null) throw StateError('No signed-in profile.');
      await ref.read(workerRepositoryProvider).requestLeave(
            workerId: job.id!,
            businessId: job.businessId,
            workerProfileId: profile.id,
            // Not-null in the database (c305ecd7de27) — Worker's own field
            // is nullable only because addWorker's local construction
            // doesn't always have it up front.
            businessName: job.businessName!,
          );
      final ownerId = await ref.read(workerRepositoryProvider).fetchBusinessOwnerId(job.businessId);
      final conversationId = await ref
          .read(messagingActionControllerProvider.notifier)
          .startOrGetConversation(ownerId, type: ConversationType.business);
      await ref.read(messagingActionControllerProvider.notifier).sendMessage(
            conversationId,
            '${profile.username} has requested to leave ${job.businessName}.',
          );
      ref.invalidate(pendingLeaveRequestProvider);
    });
  }
}
