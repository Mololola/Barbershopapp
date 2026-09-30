import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/domain/profile.dart';
import 'package:mobile/features/business/domain/business.dart';
import 'package:mobile/features/customer/application/browse_controller.dart';
import 'package:mobile/features/customer/domain/public_business.dart';
import 'package:mobile/features/customer/domain/shop_review.dart';
import 'package:mobile/features/customer/presentation/shop_page.dart';
import 'package:mobile/features/feed/application/feed_controller.dart';

void main() {
  const shop = PublicBusiness(
    id: 'biz-1',
    ownerId: 'owner-1',
    name: 'Molola Enterprises',
    currency: 'GBP',
    averageRating: 4.6,
    reviewCount: 23,
  );
  const customer = Profile(id: 'cust-1', role: AccountRole.customer, username: 'alex', referralCode: 'CODE');

  Widget buildTestable({required bool isOwner}) {
    return ProviderScope(
      overrides: [
        businessProvider(shop.id).overrideWith((ref) async => shop),
        businessOpeningHoursProvider(shop.id).overrideWith((ref) async => OpeningHours.defaultWeek()),
        businessLocationsProvider(shop.id).overrideWith(
          (ref) async => const [BusinessLocation(addressLine: '1 High St', city: 'Liverpool', postcode: 'L7 3ET', country: 'GB')],
        ),
        businessServicesProvider(shop.id).overrideWith(
          (ref) async => const [
            Service(id: 's1', businessId: 'biz-1', name: 'Skin fade', priceCents: 1800, durationMinutes: 30),
          ],
        ),
        businessWorkersProvider(shop.id).overrideWith(
          (ref) async => const [Worker(id: 'w1', businessId: 'biz-1', name: 'Jane Doe')],
        ),
        businessReviewsProvider(shop.id).overrideWith(
          (ref) async => [ShopReview(rating: 5, comment: 'Best fade in town', username: 'rob', createdAt: DateTime(2026, 9, 20))],
        ),
        postsByAuthorProvider(shop.ownerId).overrideWith((ref) async => []),
        currentProfileProvider.overrideWith((ref) async => customer),
      ],
      child: MaterialApp(home: ShopPage(businessId: shop.id, isOwner: isOwner)),
    );
  }

  Future<void> pumpTall(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(1080, 9000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  testWidgets('customers see branding, rating, bookable services, barbers and reviews', (tester) async {
    await pumpTall(tester, buildTestable(isOwner: false));

    expect(find.text('Molola Enterprises'), findsOneWidget);
    expect(find.text('ME'), findsOneWidget); // no logo -> initials
    expect(find.text(' 4.6'), findsOneWidget);
    expect(find.text(' (23)'), findsOneWidget);
    expect(find.text('Skin fade'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Book'), findsOneWidget);
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('Best fade in town'), findsOneWidget);
    expect(find.text('Message the shop'), findsOneWidget);
    expect(find.text('New post'), findsNothing);
  });

  testWidgets('the owner sees the same page with post/edit controls and no booking', (tester) async {
    await pumpTall(tester, buildTestable(isOwner: true));

    expect(find.text('Skin fade'), findsOneWidget);
    expect(find.text('New post'), findsOneWidget);
    expect(find.text('Edit page'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Book'), findsNothing);
    expect(find.text('Message the shop'), findsNothing);
  });
}
