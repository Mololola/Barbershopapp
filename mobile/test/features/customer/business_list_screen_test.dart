import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/device_location.dart';
import 'package:mobile/features/customer/application/browse_controller.dart';
import 'package:mobile/features/customer/domain/public_business.dart';
import 'package:mobile/features/customer/domain/shop_listing.dart';
import 'package:mobile/features/customer/presentation/business_list_screen.dart';

class _FakeLocation implements DeviceLocation {
  _FakeLocation(this.result);

  final ({LatLng? position, LocationProblem? problem}) result;
  int asked = 0;

  @override
  Future<({LatLng? position, LocationProblem? problem})> current() async {
    asked++;
    return result;
  }

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}

void main() {
  const camden = (latitude: 51.539, longitude: -0.1426);
  const croydon = (latitude: 51.3762, longitude: -0.0982);
  final listings = [
    // Alphabetical, as the list arrives; Croydon is the farther one.
    const ShopListing(
      business: PublicBusiness(id: 'a', ownerId: 'o1', name: 'Avenue Barbers', currency: 'GBP'),
      places: [ShopPlace(businessId: 'a', city: 'Croydon', country: 'GB', position: croydon)],
      fromPriceCents: 1800,
    ),
    const ShopListing(
      business: PublicBusiness(
        id: 'b', ownerId: 'o2', name: 'Blade Room', currency: 'GBP', averageRating: 4.6, reviewCount: 12),
      places: [ShopPlace(businessId: 'b', city: 'Camden', country: 'GB', position: camden)],
      fromPriceCents: 1200,
    ),
  ];

  Future<_FakeLocation> pump(WidgetTester tester, ({LatLng? position, LocationProblem? problem}) location) async {
    final fake = _FakeLocation(location);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        shopListingsProvider.overrideWith((ref) async => listings),
        deviceLocationProvider.overrideWithValue(fake),
      ],
      child: const MaterialApp(home: BusinessListScreen()),
    ));
    await tester.pumpAndSettle();
    return fake;
  }

  testWidgets('cards show rating, city and starting price without asking for location', (tester) async {
    final fake = await pump(tester, (position: camden, problem: null));

    expect(find.text('★ 4.6 (12) · Camden'), findsOneWidget);
    expect(find.text('New · Croydon'), findsOneWidget);
    expect(find.text('From £12'), findsOneWidget);
    expect(fake.asked, 0);
  });

  testWidgets('search finds a shop by its city', (tester) async {
    await pump(tester, (position: null, problem: null));

    await tester.enterText(find.byType(TextField), 'camd');
    await tester.pumpAndSettle();

    expect(find.text('Blade Room'), findsOneWidget);
    expect(find.text('Avenue Barbers'), findsNothing);
  });

  testWidgets('Near me sorts by distance and shows miles in the UK', (tester) async {
    // Standing in Croydon: Avenue Barbers is next door, Blade Room ~11 mi away.
    await pump(tester, (position: croydon, problem: null));
    expect(tester.getTopLeft(find.text('Avenue Barbers')).dy, lessThan(tester.getTopLeft(find.text('Blade Room')).dy));

    await tester.tap(find.text('Near me'));
    await tester.pumpAndSettle();

    expect(find.text('0.0 mi'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^1\d\.\d mi$')), findsOneWidget);
    expect(tester.getTopLeft(find.text('Avenue Barbers')).dy, lessThan(tester.getTopLeft(find.text('Blade Room')).dy));
  });

  testWidgets('Near me puts the nearest first', (tester) async {
    await pump(tester, (position: camden, problem: null));

    await tester.tap(find.text('Near me'));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Blade Room')).dy, lessThan(tester.getTopLeft(find.text('Avenue Barbers')).dy));
  });

  testWidgets('a refused location explains how to search instead', (tester) async {
    await pump(tester, (position: null, problem: LocationProblem.denied));

    await tester.tap(find.text('Near me'));
    await tester.pumpAndSettle();

    expect(find.text('Without your location, search by city instead.'), findsOneWidget);
    expect(find.textContaining(' mi'), findsNothing);
  });

  testWidgets('on the website shops are laid out in columns', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, (position: null, problem: null));

    expect(tester.getTopLeft(find.text('Avenue Barbers')).dy, tester.getTopLeft(find.text('Blade Room')).dy);
  });
}
