import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/designer/application/designer_controller.dart';
import 'package:mobile/features/designer/domain/hair_parameters.dart';
import 'package:mobile/features/designer/domain/haircut_design.dart';
import 'package:mobile/features/designer/presentation/designer_gallery_screen.dart';

void main() {
  HaircutDesign design(String id, String name, {String? ownerUsername}) {
    return HaircutDesign(
      id: id,
      ownerId: 'owner-$id',
      ownerUsername: ownerUsername,
      name: name,
      parameters: const HairParameters(),
      isPublic: ownerUsername != null,
      createdAt: DateTime.utc(2026, 8, 1),
    );
  }

  Widget buildTestable({
    required List<HaircutDesign> myDesigns,
    required List<HaircutDesign> publicDesigns,
    int extraSlots = 0,
  }) {
    return ProviderScope(
      overrides: [
        myDesignsProvider.overrideWith((ref) async => myDesigns),
        publicDesignsProvider.overrideWith((ref) async => publicDesigns),
        designExtraSlotsProvider.overrideWith((ref) async => extraSlots),
      ],
      child: const MaterialApp(home: DesignerGalleryScreen()),
    );
  }

  testWidgets('shows the free-design count and my designs', (tester) async {
    await tester.pumpWidget(buildTestable(
      myDesigns: [design('d1', 'Fade'), design('d2', 'Curls')],
      publicDesigns: [],
    ));
    await tester.pumpAndSettle();

    expect(find.text('2/$maxFreeDesigns free designs used'), findsOneWidget);
    expect(find.text('Fade'), findsOneWidget);
    expect(find.text('Curls'), findsOneWidget);
  });

  testWidgets('shows the at-cap count and browse tab designs from others', (tester) async {
    await tester.pumpWidget(buildTestable(
      myDesigns: [design('d1', 'One'), design('d2', 'Two'), design('d3', 'Three')],
      publicDesigns: [design('d4', 'Shared style', ownerUsername: 'janedoe')],
    ));
    await tester.pumpAndSettle();

    expect(find.text('3/$maxFreeDesigns free designs used'), findsOneWidget);

    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();

    expect(find.text('Shared style'), findsOneWidget);
  });

  testWidgets('shows purchased slots and the raised cap once bought', (tester) async {
    await tester.pumpWidget(buildTestable(
      myDesigns: [design('d1', 'One'), design('d2', 'Two'), design('d3', 'Three')],
      publicDesigns: [],
      extraSlots: 2,
    ));
    await tester.pumpAndSettle();

    expect(find.text('3/5 designs used ($maxFreeDesigns free + 2 purchased)'), findsOneWidget);
  });
}
