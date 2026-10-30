import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline_cache.dart';
import '../../business/domain/business.dart';
import '../domain/public_business.dart';
import '../domain/shop_listing.dart';
import '../domain/shop_review.dart';

class BrowseRepository {
  BrowseRepository(this._client, this._cache);

  final SupabaseClient _client;
  final OfflineCache _cache;

  Future<List<PublicBusiness>> fetchBusinesses() async {
    final rows = await _cache.rows('businesses', () => _client.from('businesses_public').select().eq('is_bookable', true).order('name'));
    return rows.map(PublicBusiness.fromRow).toList();
  }

  /// Every shop's cities and map positions in one query, for the shop
  /// list's cards, city search and distances.
  Future<List<ShopPlace>> fetchShopPlaces() async {
    final rows = await _cache.rows(
      'shop-places',
      () => _client.from('locations').select('business_id, city, country, latitude, longitude'),
    );
    return rows.map(ShopPlace.fromRow).toList();
  }

  /// Each shop's cheapest active service, for "From £12" on the shop list.
  Future<Map<String, int>> fetchFromPrices() async {
    final rows = await _cache.rows(
      'shop-from-prices',
      () => _client.from('services').select('business_id, price_cents').eq('is_active', true),
    );
    final prices = <String, int>{};
    for (final row in rows) {
      final businessId = row['business_id'] as String;
      final price = row['price_cents'] as int;
      if (price < (prices[businessId] ?? price + 1)) prices[businessId] = price;
    }
    return prices;
  }

  Future<PublicBusiness?> fetchBusiness(String businessId) async {
    final row = await _cache.row(
      'business:$businessId',
      () => _client.from('businesses_public').select().eq('id', businessId).maybeSingle(),
    );
    if (row == null) return null;
    return PublicBusiness.fromRow(row);
  }

  /// A business profile's shop — lets a post's author link lead to the
  /// shop page rather than a bare profile.
  Future<String?> fetchBusinessIdByOwner(String ownerId) async {
    final row = await _cache.row('business-id-by-owner:$ownerId', () => _client.from('businesses_public').select('id').eq('owner_id', ownerId).maybeSingle());
    return row?['id'] as String?;
  }

  Future<List<ShopReview>> fetchRecentReviews(String businessId, {int limit = 5}) async {
    final rows = await _cache.rows('shop-reviews:$businessId', () => _client
        .from('reviews')
        .select('shop_rating, shop_comment, created_at, customer:profiles!reviews_customer_id_fkey(username)')
        .eq('business_id', businessId)
        .not('shop_rating', 'is', null)
        .order('created_at', ascending: false)
        .limit(limit));
    return rows.map(ShopReview.fromRow).toList();
  }

  Future<List<BusinessLocation>> fetchLocations(String businessId) async {
    final rows = await _cache.rows('shop-locations:$businessId', () => _client.from('locations').select().eq('business_id', businessId));
    return rows.map(BusinessLocation.fromRow).toList();
  }

  Future<List<OpeningHours>> fetchOpeningHours(String businessId) async {
    final rows = await _cache.rows('shop-hours:$businessId', () => _client
        .from('opening_hours')
        .select()
        .eq('business_id', businessId)
        .order('day_of_week'));
    return rows.map(OpeningHours.fromRow).toList();
  }

  Future<List<Service>> fetchServices(String businessId) async {
    final rows = await _cache.rows('shop-services:$businessId', () => _client
        .from('services')
        .select()
        .eq('business_id', businessId)
        .eq('is_active', true)
        .order('name'));
    return rows.map(Service.fromRow).toList();
  }

  Future<List<Worker>> fetchWorkers(String businessId) async {
    final rows = await _cache.rows('shop-workers:$businessId', () => _client
        .from('workers')
        .select()
        .eq('business_id', businessId)
        .eq('is_active', true)
        .order('name'));
    return rows.map(Worker.fromRow).toList();
  }
}
