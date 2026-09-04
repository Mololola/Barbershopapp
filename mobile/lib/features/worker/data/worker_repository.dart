import 'package:supabase_flutter/supabase_flutter.dart';

import '../../business/domain/business.dart';
import '../domain/worker_invitation.dart';
import '../domain/worker_leave_request.dart';
import '../domain/worker_profile.dart';

class AlreadyStaffElsewhereException implements Exception {
  @override
  String toString() =>
      "You're already working at another shop — leave that role before accepting a new one.";
}

class WorkerRepository {
  WorkerRepository(this._client);

  static const _uniqueViolation = '23505';

  final SupabaseClient _client;

  Future<WorkerProfile?> fetchOwnWorkerProfile(String profileId) async {
    final row =
        await _client.from('worker_profiles').select().eq('profile_id', profileId).maybeSingle();
    if (row == null) return null;
    return WorkerProfile.fromRow(row);
  }

  Future<void> upsertWorkerProfile(WorkerProfile profile) async {
    await _client.from('worker_profiles').upsert({
      'profile_id': profile.profileId,
      'legal_first_name': profile.legalFirstName,
      'legal_last_name': profile.legalLastName,
      'legal_second_last_name': profile.legalSecondLastName,
      'bio': profile.bio,
      'city': profile.city,
      'is_looking_for_work': profile.isLookingForWork,
    });
  }

  Future<List<WorkerInvitation>> fetchReceivedInvitations(String workerProfileId) async {
    final rows = await _client
        .from('worker_invitations')
        .select()
        .eq('worker_profile_id', workerProfileId)
        .eq('status', 'pending')
        .order('created_at');
    return rows.map(WorkerInvitation.fromRow).toList();
  }

  /// See docs/architecture.md: the `workers` insert is the guarded step
  /// (protected by the one-active-business-per-profile constraint). If it
  /// fails, the invitation is left untouched. Taking a job doesn't touch
  /// `is_looking_for_work` — accepting one offer doesn't mean a worker is
  /// off the market for another; only their own explicit toggle does that.
  Future<void> acceptInvitation(WorkerInvitation invitation, String legalFullName) async {
    try {
      await _client.from('workers').insert({
        'business_id': invitation.businessId,
        'business_name': invitation.businessName,
        'profile_id': invitation.workerProfileId,
        'name': legalFullName,
      });
    } on PostgrestException catch (e) {
      if (e.code == _uniqueViolation) {
        throw AlreadyStaffElsewhereException();
      }
      rethrow;
    }

    await _client.from('worker_invitations').update({
      'status': 'accepted',
      'responded_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', invitation.id);
  }

  Future<void> declineInvitation(String invitationId) async {
    await _client.from('worker_invitations').update({
      'status': 'declined',
      'responded_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', invitationId);
  }

  Future<Worker?> fetchCurrentJob(String profileId) async {
    final row = await _client
        .from('workers')
        .select()
        .eq('profile_id', profileId)
        .eq('is_active', true)
        .maybeSingle();
    if (row == null) return null;
    return Worker.fromRow(row);
  }

  /// Doesn't deactivate the worker's own `workers` row directly anymore —
  /// leaving is no longer unilateral. This files the pending request; the
  /// business acknowledging it (business_repository.dart's
  /// acknowledgeLeaveRequest) is what actually deactivates the row and
  /// frees the one-active-business-per-profile constraint.
  Future<void> requestLeave({
    required String workerId,
    required String businessId,
    required String workerProfileId,
    required String businessName,
  }) async {
    await _client.from('worker_leave_requests').insert({
      'worker_id': workerId,
      'business_id': businessId,
      'worker_profile_id': workerProfileId,
      'business_name': businessName,
    });
  }

  /// Resolves who to message when requesting to leave — a worker can't read
  /// `businesses` directly under RLS (see 658403671135's recursion note),
  /// but `businesses_public` is readable by any authenticated user and
  /// carries owner_id.
  Future<String> fetchBusinessOwnerId(String businessId) async {
    final row =
        await _client.from('businesses_public').select('owner_id').eq('id', businessId).single();
    return row['owner_id'] as String;
  }

  Future<List<WorkerLeaveRequest>> fetchOwnLeaveRequests(String workerProfileId) async {
    final rows = await _client
        .from('worker_leave_requests')
        .select()
        .eq('worker_profile_id', workerProfileId)
        .order('requested_at', ascending: false);
    return rows.map(WorkerLeaveRequest.fromRow).toList();
  }
}
