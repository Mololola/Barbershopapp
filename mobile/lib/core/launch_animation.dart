import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import 'theme.dart';

/// The Fadra Cut launch animation ("flick open": the razor snaps open, the
/// letters spring in), played once over the app as it starts. It sits on the
/// native launch screen's charcoal (see flutter_native_splash in
/// pubspec.yaml), and the app builds underneath it, so start-up never waits
/// on it. The source is generated from the logo; see assets/branding/.
class LaunchAnimation extends StatefulWidget {
  const LaunchAnimation({super.key, required this.child});

  static const asset = 'assets/branding/fadra_launch.json';

  final Widget child;

  @override
  State<LaunchAnimation> createState() => _LaunchAnimationState();
}

class _LaunchAnimationState extends State<LaunchAnimation> with TickerProviderStateMixin {
  late final _play = AnimationController(vsync: this);
  late final _fadeOut = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  var _done = false;

  @override
  void initState() {
    super.initState();
    _play.addStatusListener((status) {
      if (status == AnimationStatus.completed) _fadeOut.forward();
    });
    _fadeOut.addStatusListener((status) {
      if (status == AnimationStatus.completed) setState(() => _done = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _done = true;
  }

  @override
  void dispose() {
    _play.dispose();
    _fadeOut.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    final size = MediaQuery.sizeOf(context);
    final markWidth = math.min(size.shortestSide * 0.9, 440.0);
    // "from Mololola" lands as CUT does, near the end of the animation.
    final maker = CurvedAnimation(parent: _play, curve: const Interval(0.62, 0.8, curve: Curves.easeOut));
    final labelStyle = Theme.of(context).textTheme.labelSmall;

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: FadeTransition(
              opacity: ReverseAnimation(_fadeOut),
              child: ColoredBox(
                color: AppColors.charcoal,
                child: Stack(
                  children: [
                    Align(
                      alignment: const Alignment(0, -0.12),
                      child: Lottie.asset(
                        LaunchAnimation.asset,
                        controller: _play,
                        width: markWidth,
                        height: markWidth,
                        onLoaded: (composition) => _play
                          ..duration = composition.duration
                          ..forward(),
                        // Never leave the app covered if the file fails to load.
                        errorBuilder: (context, error, stack) {
                          WidgetsBinding.instance.addPostFrameCallback((_) => _fadeOut.forward());
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: MediaQuery.paddingOf(context).bottom + 40,
                      child: FadeTransition(
                        opacity: maker,
                        child: Column(
                          children: [
                            Text(
                              'FROM',
                              style: labelStyle?.copyWith(color: AppColors.chalk.withValues(alpha: 0.6), letterSpacing: 1.6, fontSize: 10),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'MOLOLOLA',
                              style: labelStyle?.copyWith(
                                color: AppColors.chalk,
                                letterSpacing: 4,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
