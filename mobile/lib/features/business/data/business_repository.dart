import 'package:supabase_flutter/supabase_flutter.dart';

import '../../worker/domain/worker_invitation.dart';
import '../../worker/domain/worker_leave_request.dart';
import '../../worker/domain/worker_profile.dart';
import '../domain/business.dart';
import '../domain/business_finance_access.dart';
import '../domain/business_subscription.dart';

class InvalidReferralCodeException implements Exception {
  @override
  String toString() => 'That referral code doesn\'t exist.';
}

class AlreadyInvitedException implements Exception {
  @override
  String toString() => "You already have a pending invitation out to this worker.";
}

/// A change to the staff the database refused for a business reason — the
/// message is written for the user (see the migration's BB00x triggers):
/// a worker with upcoming bookings can't be taken off the staff, and
/// someone already on it can't be invited again.
class StaffChangeBlockedException implements Exception {
  const StaffChangeBlockedException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _staffGuardCodes = {'BB001', 'BB002'};

class BusinessRepository {
  BusinessRepository(this._client);

  static const _foreignKeyViolation = '23503';
  static const _uniqueViolation = '23505';

  final SupabaseClient _client;

  Future<void> _guardStaffChange(Future<void> Function() change) async {
    try {
      await change();
    } on PostgrestException catch (e) {
      if (_staffGuardCodes.contains(e.code)) throw StaffChangeBlockedException(e.message);
      rethrow;
    }
  }

  Future<BusinessSubscription?> fetchSubscription(String businessId) async {
    final row = await _client
        .from('business_subscriptions')
        .select()
        .eq('business_id', businessId)
        .maybeSingle();
    if (row == null) return null;
    return BusinessSubscription.fromRow(row);
  }

  Future<BusinessFinanceAccess?> fetchFinanceAccess(String businessId) async {
    final row = await _client
        .from('business_finance_access')
        .select()
        .eq('business_id', businessId)
        .maybeSingle();
    if (row == null) return null;
    return BusinessFinanceAccess.fromRow(row);
  }

  Future<Business?> fetchOwnBusiness(String ownerId) async {
    final row = await _client.from('businesses').select().eq('owner_id', ownerId).maybeSingle();
    if (row == null) return null;
    return Business.fromRow(row);
  }

  /// Creates the business plus its locations and opening hours as sequential
  /// inserts (see docs/architecture.md for why this isn't a single DB
  /// transaction: it's a one-time, non-concurrent setup action).
  Future<Business> createBusiness({
    required String ownerId,
    required String name,
    String? phone,
    required String currency,
    required List<BusinessLocation> locations,
    required List<OpeningHours> openingHours,
    String? referredByCode,
  }) async {
    final Map<String, dynamic> businessRow;
    try {
      businessRow = await _client
          .from('businesses')
          .insert({
            'owner_id': ownerId,
            'name': name,
            'phone': phone,
            'currency': currency,
            'referred_by_code': referredByCode,
            // Hours are per business, so the first location's zone is the
            // business's — see the businesses_time_zone_check migration.
            'time_zone': locations.first.timeZone,
          })
          .select()
          .single();
    } on PostgrestException catch (e) {
      if (e.code == _foreignKeyViolation) {
        throw InvalidReferralCodeException();
      }
      rethrow;
    }
    final business = Business.fromRow(businessRow);

    await _client.from('locations').insert([for (final location in locations) location.toRow(business.id)]);

    await _client.from('opening_hours').insert([
      for (final hours in openingHours) {'business_id': business.id, ...hours.toRow()},
    ]);

    return business;
  }

  Future<List<BusinessLocation>> fetchLocations(String businessId) async {
    final rows = await _client.from('locations').select().eq('business_id', businessId);
    return rows.map(BusinessLocation.fromRow).toList();
  }

  /// Delete-then-reinsert — same "one-time, non-concurrent config action"
  /// reasoning as [createBusiness]'s location inserts, not a high-frequency
  /// or concurrent write path that would need real diffing.
  Future<void> updateLocations(String businessId, List<BusinessLocation> locations) async {
    await _client.from('locations').delete().eq('business_id', businessId);
    await _client.from('locations').insert([for (final location in locations) location.toRow(businessId)]);
    await _client.from('businesses').update({'time_zone': locations.first.timeZone}).eq('id', businessId);
  }

  Future<void> updateOpeningHours(String businessId, List<OpeningHours> hours) async {
    await _client.from('opening_hours').upsert(
      [for (final h in hours) {'business_id': businessId, ...h.toRow()}],
      onConflict: 'business_id,day_of_week',
    );
  }

  Future<void> markSetupComplete(String businessId) async {
    await _client
        .from('businesses')
        .update({'setup_completed_at': DateTime.now().toUtc().toIso8601String()}).eq('id', businessId);
  }

  Future<void> updateLogoUrl(String businessId, String logoUrl) async {
    await _client.from('businesses').update({'logo_url': logoUrl}).eq('id', businessId);
  }

  Future<List<OpeningHours>> fetchWorkerSchedule(String workerId) async {
    final rows = await _client
        .from('worker_schedules')
        .select()
        .eq('worker_id', workerId)
        .order('day_of_week');
    return rows.map(OpeningHours.fromRow).toList();
  }

  /// Always writes all 7 days — a worker with no rows yet falls back to the
  /// business's own opening hours (see the availability endpoint); once
  /// saved here, these rows are authoritative for that worker.
  Future<void> updateWorkerSchedule(String workerId, List<OpeningHours> hours) async {
    await _client.from('worker_schedules').upsert(
      [for (final h in hours) {'worker_id': workerId, ...h.toRow()}],
      onConflict: 'worker_id,day_of_week',
    );
  }

  Future<List<OpeningHours>> fetchOpeningHours(String businessId) async {
    final rows = await _client
        .from('opening_hours')
        .select()
        .eq('business_id', businessId)
        .order('day_of_week');
    return rows.map(OpeningHours.fromRow).toList();
  }

  Future<List<Service>> fetchServices(String businessId) async {
    final rows = await _client
        .from('services')
        .select()
        .eq('business_id', businessId)
        .order('created_at');
    return rows.map(Service.fromRow).toList();
  }

  Future<void> addService(Service service) async {
    await _client.from('services').insert({
      'business_id': service.businessId,
      'name': service.name,
      'price_cents': service.priceCents,
      'duration_minutes': service.durationMinutes,
    });
  }

  Future<void> deleteService(String serviceId) async {
    await _client.from('services').delete().eq('id', serviceId);
  }

  Future<List<CostItem>> fetchCostItems(String businessId) async {
    final rows = await _client
        .from('business_cost_items')
        .select()
        .eq('business_id', businessId)
        .order('created_at');
    return rows.map(CostItem.fromRow).toList();
  }

  Future<void> addCostItem(String businessId, String label, int amountCents) async {
    await _client.from('business_cost_items').insert({
      'business_id': businessId,
      'label': label,
      'amount_cents': amountCents,
    });
  }

  Future<void> deleteCostItem(String costItemId) async {
    await _client.from('business_cost_items').delete().eq('id', costItemId);
  }

  /// Current staff only — removed workers and ones who've left keep their
  /// (inactive) row for history, but aren't staff anymore.
  Future<List<Worker>> fetchWorkers(String businessId) async {
    final rows = await _client
        .from('workers')
        .select()
        .eq('business_id', businessId)
        .eq('is_active', true)
        .order('created_at');
    return rows.map(Worker.fromRow).toList();
  }

  Future<void> addWorker(Worker worker) async {
    await _client.from('workers').insert({
      'business_id': worker.businessId,
      'business_name': worker.businessName,
      'name': worker.name,
    });
  }

  /// Deactivates rather than deletes — same reasoning as the worker's own
  /// leaveCurrentJob (worker_repository.dart): keeps the employment history
  /// around so "shops worked at" stays a truthful count for this person
  /// across every business, not just whoever hasn't fired them yet.
  /// Throws [StaffChangeBlockedException] while they have upcoming bookings.
  Future<void> removeWorker(String workerId) async {
    await _guardStaffChange(() => _client.from('workers').update({'is_active': false}).eq('id', workerId));
  }

  /// Looked up by real (legal) name, not account username — per-field
  /// case-insensitive exact match. Only ever returns profiles that have
  /// opted into worker mode and are currently looking for work (enforced by
  /// RLS on `worker_profiles`, not just this query — see the migration).
  /// Returns every match so the caller can detect same-name collisions
  /// (disambiguated by supplying a second last name) instead of guessing.
  Future<List<WorkerSearchResult>> findWorkersByName({
    required String firstName,
    required String lastName,
    String? secondLastName,
  }) async {
    var query = _client
        .from('profiles')
        .select(
          'id, username, '
          'worker_profiles!inner(legal_first_name, legal_last_name, legal_second_last_name, '
          'bio, city, is_looking_for_work)',
        )
        .eq('worker_profiles.is_looking_for_work', true)
        .ilike('worker_profiles.legal_first_name', firstName)
        .ilike('worker_profiles.legal_last_name', lastName);
    if (secondLastName != null && secondLastName.isNotEmpty) {
      query = query.ilike('worker_profiles.legal_second_last_name', secondLastName);
    }

    final rows = await query;
    return rows.map((row) {
      final workerProfile = row['worker_profiles'] as Map<String, dynamic>;
      return WorkerSearchResult(
        profileId: row['id'] as String,
        username: row['username'] as String,
        legalFirstName: workerProfile['legal_first_name'] as String,
        legalLastName: workerProfile['legal_last_name'] as String,
        legalSecondLastName: workerProfile['legal_second_last_name'] as String?,
        bio: workerProfile['bio'] as String?,
        city: workerProfile['city'] as String?,
      );
    }).toList();
  }

  /// The Available Workers marketplace: paginated (this list can run into
  /// the thousands), name-searchable, and filterable on the server-computed
  /// aggregates (worker_shops_worked_count/worker_average_rating are
  /// PostgREST computed columns on worker_profiles — see the migration —
  /// not client-side math, so a candidate can't inflate their own standing).
  /// Deliberately does NOT exclude anyone currently employed elsewhere —
  /// taking one job doesn't take a worker off the market for another,
  /// only their own is_looking_for_work toggle does that.
  Future<List<WorkerSearchResult>> fetchWorkersLookingForWork({
    String? nameQuery,
    int? minYearsExperience,
    int? minShopsWorked,
    double? minAverageRating,
    required int offset,
    required int limit,
  }) async {
    var query = _client
        .from('profiles')
        .select(
          'id, username, '
          'worker_profiles!inner(legal_first_name, legal_last_name, legal_second_last_name, '
          'bio, city, years_experience, is_looking_for_work, '
          'worker_shops_worked_count, worker_average_rating)',
        )
        .eq('worker_profiles.is_looking_for_work', true);

    final trimmedQuery = nameQuery?.trim();
    if (trimmedQuery != null && trimmedQuery.isNotEmpty) {
      query = query.or(
        'legal_first_name.ilike.%$trimmedQuery%,legal_last_name.ilike.%$trimmedQuery%',
        referencedTable: 'worker_profiles',
      );
    }
    if (minYearsExperience != null) {
      query = query.gte('worker_profiles.years_experience', minYearsExperience);
    }
    if (minShopsWorked != null) {
      query = query.gte('worker_profiles.worker_shops_worked_count', minShopsWorked);
    }
    if (minAverageRating != null) {
      query = query.gte('worker_profiles.worker_average_rating', minAverageRating);
    }

    final rows = await query.order('username').range(offset, offset + limit - 1);

    return rows.map((row) {
      final workerProfile = row['worker_profiles'] as Map<String, dynamic>;
      return WorkerSearchResult(
        profileId: row['id'] as String,
        username: row['username'] as String,
        legalFirstName: workerProfile['legal_first_name'] as String,
        legalLastName: workerProfile['legal_last_name'] as String,
        legalSecondLastName: workerProfile['legal_second_last_name'] as String?,
        bio: workerProfile['bio'] as String?,
        city: workerProfile['city'] as String?,
        yearsExperience: workerProfile['years_experience'] as int?,
        shopsWorkedCount: workerProfile['worker_shops_worked_count'] as int?,
        averageRating: (workerProfile['worker_average_rating'] as num?)?.toDouble(),
      );
    }).toList();
  }

  Future<void> createInvitation({
    required String businessId,
    required String businessName,
    required String workerProfileId,
  }) async {
    try {
      await _guardStaffChange(() => _client.from('worker_invitations').insert({
            'business_id': businessId,
            'business_name': businessName,
            'worker_profile_id': workerProfileId,
          }));
    } on PostgrestException catch (e) {
      if (e.code == _uniqueViolation) throw AlreadyInvitedException();
      rethrow;
    }
  }

  Future<List<WorkerInvitation>> fetchSentInvitations(String businessId) async {
    final rows = await _client
        .from('worker_invitations')
        .select(
          '*, profiles(username, worker_profiles(legal_first_name, legal_last_name, legal_second_last_name))',
        )
        .eq('business_id', businessId)
        .order('created_at', ascending: false);
    return rows.map(WorkerInvitation.fromRow).toList();
  }

  Future<List<WorkerLeaveRequest>> fetchPendingLeaveRequests(String businessId) async {
    final rows = await _client
        .from('worker_leave_requests')
        .select()
        .eq('business_id', businessId)
        .eq('status', 'pending')
        .order('requested_at');
    return rows.map(WorkerLeaveRequest.fromRow).toList();
  }

  /// The worker doesn't actually leave until this runs — resolving the
  /// request and deactivating the `workers` row together, not on the
  /// worker's own say-so (see requestLeave in worker_repository.dart).
  /// Deactivates the worker first: that's the step that can be refused
  /// (upcoming bookings — [StaffChangeBlockedException]), and doing it first
  /// means a refusal leaves the request pending rather than marked done
  /// while they're still on staff. Safe to retry — deactivating an already
  /// inactive row is a no-op.
  Future<void> acknowledgeLeaveRequest(WorkerLeaveRequest request) async {
    await removeWorker(request.workerId);
    await _client.from('worker_leave_requests').update({
      'status': 'acknowledged',
      'resolved_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', request.id);
  }

  /// A misclick, or the shop isn't ready to let them go — resolves the
  /// request without touching the `workers` row, so the job stays active.
  Future<void> rejectLeaveRequest(WorkerLeaveRequest request) async {
    await _client.from('worker_leave_requests').update({
      'status': 'rejected',
      'resolved_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', request.id);
  }
}
