import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:mobile/core/launch_animation.dart';

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

  testWidgets('with reduced motion the app opens straight away', (tester) async {
    await tester.pumpWidget(buildTestable(reduceMotion: true));

    expect(find.byType(Lottie), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });
}
