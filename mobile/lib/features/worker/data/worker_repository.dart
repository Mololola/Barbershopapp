import 'package:supabase_flutter/supabase_flutter.dart';

import '../../business/domain/business.dart';
import '../domain/worker_invitation.dart';
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
  /// (protected by the one-active-business-per-profile constraint). Only if
  /// it succeeds do we flip the worker off "looking for work" and mark the
  /// invitation accepted — if it fails, the invitation is left untouched.
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

    await _client
        .from('worker_profiles')
        .update({'is_looking_for_work': false}).eq('profile_id', invitation.workerProfileId);
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

  /// Deactivates the worker's own `workers` row rather than deleting it,
  /// keeping the staffing history around; frees the one-active-business-per-
  /// profile constraint so they can join elsewhere.
  Future<void> leaveCurrentJob(String workerId) async {
    await _client.from('workers').update({'is_active': false}).eq('id', workerId);
  }
}
