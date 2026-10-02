import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/designer/presentation/color_picker.dart';

void main() {
  Widget buildTestable(String hex, ValueChanged<String> onChanged) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ColorPicker(hex: hex, swatches: const ['#0a0a0a', '#c8a165'], onChanged: onChanged),
        ),
      ),
    );
  }

  test('hex and colour convert both ways', () {
    expect(hexFromColor(colorFromHex('#8a3324')), '#8a3324');
  });

  testWidgets('tapping a swatch picks its exact colour', (tester) async {
    String? picked;
    await tester.pumpWidget(buildTestable('#0a0a0a', (hex) => picked = hex));

    await tester.tap(find.bySemanticsLabel('#c8a165'));
    expect(picked, '#c8a165');
  });

  testWidgets('typing a hex code picks that colour; a partial code does nothing', (tester) async {
    String? picked;
    await tester.pumpWidget(buildTestable('#0a0a0a', (hex) => picked = hex));

    await tester.enterText(find.byType(TextField), '#12ab3');
    expect(picked, isNull);
    await tester.enterText(find.byType(TextField), '#12AB34');
    expect(picked, '#12ab34');
  });
}
