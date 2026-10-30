import 'dart:math';

import '../../../core/device_location.dart';
import 'public_business.dart';

/// One of a shop's addresses, as the shop list needs it. [position] is null
/// until the backend has looked the postcode up (every few hours).
class ShopPlace {
  const ShopPlace({required this.businessId, required this.city, required this.country, this.position});

  final String businessId;
  final String city;
  final String country;
  final LatLng? position;

  factory ShopPlace.fromRow(Map<String, dynamic> row) {
    final latitude = (row['latitude'] as num?)?.toDouble();
    final longitude = (row['longitude'] as num?)?.toDouble();
    return ShopPlace(
      businessId: row['business_id'] as String,
      city: row['city'] as String,
      country: row['country'] as String,
      position: latitude == null || longitude == null ? null : (latitude: latitude, longitude: longitude),
    );
  }
}

/// A shop in the Find a shop list: what it is, where, and its cheapest service.
class ShopListing {
  const ShopListing({required this.business, required this.places, this.fromPriceCents});

  final PublicBusiness business;
  final List<ShopPlace> places;
  final int? fromPriceCents;

  List<String> get cities => {for (final place in places) place.city}.toList();

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    return business.name.toLowerCase().contains(needle) || cities.any((city) => city.toLowerCase().contains(needle));
  }

  /// To the nearest of its addresses, or null when none has been located yet.
  ({double km, String country})? nearestFrom(LatLng from) {
    ({double km, String country})? nearest;
    for (final place in places) {
      final position = place.position;
      if (position == null) continue;
      final km = distanceKm(from, position);
      if (nearest == null || km < nearest.km) nearest = (km: km, country: place.country);
    }
    return nearest;
  }
}

/// Great-circle distance (haversine); plenty for "which shop is nearer".
double distanceKm(LatLng a, LatLng b) {
  const earthRadiusKm = 6371.0;
  double radians(double degrees) => degrees * pi / 180;
  final dLat = radians(b.latitude - a.latitude);
  final dLng = radians(b.longitude - a.longitude);
  final h = pow(sin(dLat / 2), 2) + cos(radians(a.latitude)) * cos(radians(b.latitude)) * pow(sin(dLng / 2), 2);
  return 2 * earthRadiusKm * asin(sqrt(h));
}
