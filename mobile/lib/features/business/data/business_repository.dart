import 'package:supabase_flutter/supabase_flutter.dart';

import '../../worker/domain/worker_invitation.dart';
import '../../worker/domain/worker_profile.dart';
import '../domain/business.dart';

class BusinessRepository {
  BusinessRepository(this._client);

  final SupabaseClient _client;

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
  }) async {
    final businessRow = await _client
        .from('businesses')
        .insert({'owner_id': ownerId, 'name': name, 'phone': phone, 'currency': currency})
        .select()
        .single();
    final business = Business.fromRow(businessRow);

    await _client.from('locations').insert([
      for (final location in locations)
        {'business_id': business.id, 'address_line': location.addressLine, 'city': location.city},
    ]);

    await _client.from('opening_hours').insert([
      for (final hours in openingHours)
        {
          'business_id': business.id,
          'day_of_week': hours.dayOfWeek,
          'is_closed': hours.isClosed,
          'open_time': timeOfDayToSql(hours.openTime),
          'close_time': timeOfDayToSql(hours.closeTime),
        },
    ]);

    return business;
  }

  Future<List<BusinessLocation>> fetchLocations(String businessId) async {
    final rows = await _client.from('locations').select().eq('business_id', businessId);
    return rows.map(BusinessLocation.fromRow).toList();
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

  Future<List<Worker>> fetchWorkers(String businessId) async {
    final rows = await _client
        .from('workers')
        .select()
        .eq('business_id', businessId)
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

  Future<void> deleteWorker(String workerId) async {
    await _client.from('workers').delete().eq('id', workerId);
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

  Future<void> createInvitation({
    required String businessId,
    required String businessName,
    required String workerProfileId,
  }) async {
    await _client.from('worker_invitations').insert({
      'business_id': businessId,
      'business_name': businessName,
      'worker_profile_id': workerProfileId,
    });
  }

  Future<List<WorkerInvitation>> fetchSentInvitations(String businessId) async {
    final rows = await _client
        .from('worker_invitations')
        .select(
          '*, profiles(username, worker_profiles(legal_first_name, legal_last_name, legal_second_last_name))',
        )
        .eq('business_id', businessId)
        .order('created_at');
    return rows.map(WorkerInvitation.fromRow).toList();
  }
}
