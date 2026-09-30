import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Keeps every screen clear of the phone's own navigation bar (the gesture
/// handle or back/home/recents buttons).
///
/// Android 15+ draws apps edge-to-edge, under that bar, and leaves it to
/// each screen to stay out of the way. Tab screens did (NavigationBar
/// handles it); screens pushed over them — comments, settings, forms —
/// didn't, and their bottom content ended up under the system buttons.
/// Applied once around the whole app instead, so every screen, dialog and
/// sheet is covered, including ones added later.
///
/// The strip behind the system bar takes the tab bar's colour, so on tab
/// screens the two read as one bar. The system buttons are drawn dark,
/// without Android's translucent scrim, to sit cleanly on that strip —
/// this region spans the whole screen, so it's the one Flutter reads the
/// navigation-bar style from (AppBar's own style only covers the top).
class SystemBarsSafeArea extends StatelessWidget {
  const SystemBarsSafeArea({super.key, required this.child});

  final Widget child;

  static const overlayStyle = SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: ColoredBox(
        color: AppColors.cardSurface,
        // Bottom only: the app bar already handles the status bar, and
        // side insets are zero in portrait.
        child: SafeArea(top: false, left: false, right: false, child: child),
      ),
    );
  }
}
