import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/domain/profile.dart';
import '../../customer/domain/review.dart';
import '../../rewards/domain/payout_request.dart';
import '../domain/admin_business_summary.dart';

/// Admin-only actions — `setQualityReviewer` relies entirely on the
/// "admin update quality reviewer flag" RLS policy (see the migration) to
/// reject the write server-side for any caller whose own profile isn't
/// flagged `is_admin`; this repository does no authorization itself.
class AdminRepository {
  AdminRepository(this._client);

  final SupabaseClient _client;

  Future<List<Profile>> searchCustomers(String query) async {
    final rows = await _client
        .from('profiles')
        .select()
        .eq('role', 'customer')
        .ilike('username', '%$query%')
        .limit(20);
    return rows.map(Profile.fromRow).toList();
  }

  Future<List<Review>> fetchReviewsByCustomer(String customerId) async {
    final rows = await _client
        .from('reviews')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
    return rows.map(Review.fromRow).toList();
  }

  Future<void> setQualityReviewer(String customerId, bool value) async {
    await _client.from('profiles').update({'is_quality_reviewer': value}).eq('id', customerId);
  }

  /// Relies on the "admin select all businesses"/"admin select all
  /// business_subscriptions" RLS policies — a non-admin caller would just
  /// get their own business back (if any), same as any owner-scoped query.
  Future<List<AdminBusinessSummary>> fetchBusinesses() async {
    final rows = await _client
        .from('businesses')
        // businesses has two foreign keys to profiles (owner_id, and
        // referred_by_code -> referral_code), so the owner embed must name
        // its FK or PostgREST refuses the query as ambiguous.
        .select(
          'id, name, created_at, subscription_trial_ends_at, '
          'owner:profiles!businesses_owner_id_fkey(username), business_subscriptions(status)',
        )
        .order('created_at', ascending: false);
    return rows.map(AdminBusinessSummary.fromRow).toList();
  }

  Future<void> grantTrial(String businessId) async {
    final trialEndsAt = DateTime.now().toUtc().add(const Duration(days: 30));
    await _client
        .from('businesses')
        .update({'subscription_trial_ends_at': trialEndsAt.toIso8601String()}).eq('id', businessId);
  }

  Future<List<PayoutRequest>> fetchAllPayoutRequests() async {
    final rows = await _client
        .from('payout_requests')
        .select('*, profiles(username)')
        .order('requested_at', ascending: false);
    return rows.map(PayoutRequest.fromRow).toList();
  }

  Future<void> resolvePayoutRequest({
    required String requestId,
    required PayoutRequestStatus status,
    String? adminNote,
  }) async {
    await _client.from('payout_requests').update({
      'status': status.wireValue,
      'resolved_at': DateTime.now().toUtc().toIso8601String(),
      if (adminNote != null) 'admin_note': adminNote,
    }).eq('id', requestId);
  }
}
