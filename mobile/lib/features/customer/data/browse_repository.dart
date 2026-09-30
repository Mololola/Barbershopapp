import 'package:supabase_flutter/supabase_flutter.dart';

import '../../business/domain/business.dart';
import '../domain/public_business.dart';
import '../domain/shop_review.dart';

class BrowseRepository {
  BrowseRepository(this._client);

  final SupabaseClient _client;

  Future<List<PublicBusiness>> fetchBusinesses() async {
    final rows = await _client.from('businesses_public').select().eq('is_bookable', true).order('name');
    return rows.map(PublicBusiness.fromRow).toList();
  }

  Future<PublicBusiness?> fetchBusiness(String businessId) async {
    final row =
        await _client.from('businesses_public').select().eq('id', businessId).maybeSingle();
    if (row == null) return null;
    return PublicBusiness.fromRow(row);
  }

  /// A business profile's shop — lets a post's author link lead to the
  /// shop page rather than a bare profile.
  Future<String?> fetchBusinessIdByOwner(String ownerId) async {
    final row = await _client.from('businesses_public').select('id').eq('owner_id', ownerId).maybeSingle();
    return row?['id'] as String?;
  }

  Future<List<ShopReview>> fetchRecentReviews(String businessId, {int limit = 5}) async {
    final rows = await _client
        .from('reviews')
        .select('shop_rating, shop_comment, created_at, customer:profiles!reviews_customer_id_fkey(username)')
        .eq('business_id', businessId)
        .not('shop_rating', 'is', null)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(ShopReview.fromRow).toList();
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
        .eq('is_active', true)
        .order('name');
    return rows.map(Service.fromRow).toList();
  }

  Future<List<Worker>> fetchWorkers(String businessId) async {
    final rows = await _client
        .from('workers')
        .select()
        .eq('business_id', businessId)
        .eq('is_active', true)
        .order('name');
    return rows.map(Worker.fromRow).toList();
  }
}
