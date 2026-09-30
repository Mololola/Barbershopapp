import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/system_bars.dart';

void main() {
  // A phone with a 48dp system navigation bar (3-button mode), at 360x800dp.
  void phoneWithNavBar(WidgetTester tester) {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.padding = const FakeViewPadding(bottom: 144);
    tester.view.viewPadding = const FakeViewPadding(bottom: 144);
    addTearDown(tester.view.reset);
  }

  testWidgets('a pushed, full-screen page ends above the system navigation bar', (tester) async {
    phoneWithNavBar(tester);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => SystemBarsSafeArea(child: child!),
      // Like the Comments screen: an input pinned to the bottom of the body.
      home: const Scaffold(
        body: Column(
          children: [Spacer(), SizedBox(height: 56, child: Text('Add a comment', key: Key('input')))],
        ),
      ),
    ));

    expect(tester.getRect(find.byKey(const Key('input'))).bottom, 800 - 48);
  });

  testWidgets('the tab bar sits above the system bar, not doubled up', (tester) async {
    phoneWithNavBar(tester);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => SystemBarsSafeArea(child: child!),
      home: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: NavigationBar(
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    ));

    // Flush with the top of the system bar — no extra gap from the bar
    // applying the same inset a second time.
    expect(tester.getRect(find.byType(NavigationBar)).bottom, 800 - 48);
  });

  testWidgets('asks for dark system buttons with no translucent scrim', (tester) async {
    await tester.pumpWidget(const SystemBarsSafeArea(child: SizedBox()));

    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    expect(region.value.systemNavigationBarIconBrightness, Brightness.dark);
    expect(region.value.systemNavigationBarContrastEnforced, isFalse);
  });
}
