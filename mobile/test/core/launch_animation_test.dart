import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:mobile/core/launch_animation.dart';
import 'package:mobile/core/theme.dart';

void main() {
  Widget buildTestable({bool reduceMotion = false}) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: LaunchAnimation(child: child!),
        ),
        home: const Scaffold(body: Text('Home')),
      );

  testWidgets('plays over the app, which is already built underneath, then gets out of the way', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(buildTestable());
      // Let the Lottie file load from the asset bundle.
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    expect(find.byType(Lottie), findsOneWidget);
    expect(find.text('MOLOLOLA'), findsOneWidget);
    expect(find.text('Home', skipOffstage: false), findsOneWidget);

    // Still playing a second in, so the file loaded (a failed load closes it at once).
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(Lottie), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.byType(Lottie), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });

  // Rendered by the same Lottie player the app uses: the web player forgives
  // things this one doesn't (a lone "intersect" mask hid the wordmark).
  testWidgets('every part of the logo is drawn on the final frame', (tester) async {
    final boundary = GlobalKey();
    late LottieComposition composition;
    await tester.runAsync(() async => composition = await AssetLottie(LaunchAnimation.asset).load());
    await tester.pumpWidget(Center(
      child: RepaintBoundary(
        key: boundary,
        child: SizedBox.square(
          dimension: 500,
          child: Lottie(composition: composition, controller: const AlwaysStoppedAnimation(1.0)),
        ),
      ),
    ));

    late ByteData pixels;
    await tester.runAsync(() async {
      final image = await (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
      pixels = (await image.toByteData(format: ImageByteFormat.rawRgba))!;
    });
    // Pixels close to `colour` inside `area` (the animation is 1000 units square, drawn at 500).
    int count(Color colour, Rect area) {
      var n = 0;
      for (var y = area.top ~/ 2; y < area.bottom ~/ 2; y++) {
        for (var x = area.left ~/ 2; x < area.right ~/ 2; x++) {
          final i = (y * 500 + x) * 4;
          final r = pixels.getUint8(i), g = pixels.getUint8(i + 1), b = pixels.getUint8(i + 2);
          if ((r - (colour.r * 255)).abs() < 24 && (g - (colour.g * 255)).abs() < 24 && (b - (colour.b * 255)).abs() < 24) n++;
        }
      }
      return n;
    }

    expect(count(AppColors.brass, const Rect.fromLTRB(250, 80, 750, 380)), greaterThan(2000), reason: 'F and c');
    expect(count(AppColors.chalk, const Rect.fromLTRB(250, 380, 800, 480)), greaterThan(1000), reason: 'razor blade');
    expect(count(AppColors.chalk, const Rect.fromLTRB(200, 540, 800, 760)), greaterThan(2000), reason: 'Fadra');
    expect(count(AppColors.brass, const Rect.fromLTRB(300, 800, 700, 900)), greaterThan(150), reason: 'CUT');
  });

  testWidgets('with reduced motion the app opens straight away', (tester) async {
    await tester.pumpWidget(buildTestable(reduceMotion: true));

    expect(find.byType(Lottie), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });
}
