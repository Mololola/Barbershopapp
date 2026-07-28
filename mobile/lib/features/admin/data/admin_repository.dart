import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/domain/profile.dart';
import '../../customer/domain/review.dart';

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
}
