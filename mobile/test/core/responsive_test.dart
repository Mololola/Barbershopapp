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
}
