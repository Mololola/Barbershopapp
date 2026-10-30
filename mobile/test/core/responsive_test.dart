import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/responsive.dart';

void main() {
  Future<void> pumpAtWidth(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResponsiveColumns(children: [Text('left'), Text('right')]),
        ),
      ),
    );
  }

  testWidgets('side by side when both fit', (tester) async {
    await pumpAtWidth(tester, 1200);
    expect(tester.getTopLeft(find.text('left')).dy, tester.getTopLeft(find.text('right')).dy);
  });

  testWidgets('stacked, in order, on a phone', (tester) async {
    await pumpAtWidth(tester, 400);
    expect(tester.getTopLeft(find.text('right')).dy, greaterThan(tester.getTopLeft(find.text('left')).dy));
  });

  test('tile columns: two on a phone, up to four on a desktop', () {
    expect(columnsFor(360, minWidth: 220), 2);
    expect(columnsFor(700, minWidth: 220), 3);
    expect(columnsFor(1300, minWidth: 220), 4);
  });

  testWidgets('TileGrid fits as many columns as the width allows, up to the cap', (tester) async {
    Future<int> columnsAt(double width) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: TileGrid(children: [for (var i = 0; i < 4; i++) Text('tile $i')])),
      ));
      // Tiles on the first row share tile 0's top edge.
      final firstRow = tester.getTopLeft(find.text('tile 0')).dy;
      return [for (var i = 0; i < 4; i++) tester.getTopLeft(find.text('tile $i')).dy].where((dy) => dy == firstRow).length;
    }
    addTearDown(tester.view.reset);

    expect(await columnsAt(1400), 3);
    expect(await columnsAt(800), 2);
    expect(await columnsAt(400), 1);
  });
}
