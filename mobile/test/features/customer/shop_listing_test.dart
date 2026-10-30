import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/customer/domain/public_business.dart';
import 'package:mobile/features/customer/domain/shop_listing.dart';

void main() {
  const london = (latitude: 51.5072, longitude: -0.1276);
  const madrid = (latitude: 40.4168, longitude: -3.7038);

  ShopListing shop(String name, List<ShopPlace> places) => ShopListing(
        business: PublicBusiness(id: name, ownerId: 'o', name: name, currency: 'GBP'),
        places: places,
      );

  test('distances are right to within a few kilometres', () {
    expect(distanceKm(london, madrid), closeTo(1264, 5));
    expect(distanceKm(london, london), 0);
  });

  test('search matches the name or any of the cities, ignoring case', () {
    final listing = shop('Fresh Cuts', [
      const ShopPlace(businessId: 'Fresh Cuts', city: 'Camden', country: 'GB'),
      const ShopPlace(businessId: 'Fresh Cuts', city: 'Hackney', country: 'GB'),
    ]);

    expect(listing.matches('fresh'), isTrue);
    expect(listing.matches('hack'), isTrue);
    expect(listing.matches('madrid'), isFalse);
  });

  test('the nearest located address counts, and none located means no distance', () {
    final listing = shop('Two Shops', [
      const ShopPlace(businessId: 'Two Shops', city: 'Madrid', country: 'ES', position: madrid),
      const ShopPlace(businessId: 'Two Shops', city: 'London', country: 'GB', position: london),
      const ShopPlace(businessId: 'Two Shops', city: 'Nowhere', country: 'GB'),
    ]);

    final nearest = listing.nearestFrom((latitude: 51.5, longitude: -0.12))!;
    expect(nearest.country, 'GB');
    expect(nearest.km, lessThan(2));
    expect(shop('Unlocated', const []).nearestFrom(london), isNull);
  });
}
