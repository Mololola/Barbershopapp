import 'package:flutter/material.dart';

import 'theme.dart';

/// Placeholders in the shape of the content that's on its way: grey shapes
/// where the text and pictures will go, gently pulsing. Calmer than a
/// spinner in an empty space, and nothing jumps when the content arrives.
/// For lists and cards; small or one-off loads keep [LoadingView].
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Held still for people who've asked the phone for less motion.
    if (MediaQuery.of(context).disableAnimations) return Opacity(opacity: 0.7, child: widget.child);
    return FadeTransition(
      opacity: _controller.drive(Tween(begin: 0.45, end: 1.0)),
      child: widget.child,
    );
  }
}

/// One grey shape. [color] for shapes on a dark card.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 6, this.color});

  final double? width;
  final double height;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? AppColors.divider.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

enum SkeletonLeading { none, avatar, square }

/// A list of [count] card rows like the app's list screens: an optional
/// avatar or picture, a title line and a shorter line under it.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 6, this.leading = SkeletonLeading.none, this.padding});

  final int count;
  final SkeletonLeading leading;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding ?? const EdgeInsets.symmetric(vertical: 8),
        itemCount: count,
        itemBuilder: (context, i) => Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                if (leading == SkeletonLeading.avatar) const SkeletonBox(width: 44, height: 44, radius: 22),
                if (leading == SkeletonLeading.square) const SkeletonBox(width: 52, height: 52, radius: 10),
                if (leading != SkeletonLeading.none) const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Varied widths read as text rather than a grid of bars.
                      FractionallySizedBox(widthFactor: i.isEven ? 0.6 : 0.45, child: const SkeletonBox(height: 14)),
                      const SizedBox(height: 8),
                      FractionallySizedBox(widthFactor: i.isEven ? 0.35 : 0.5, child: const SkeletonBox(height: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A few short lines, for a section of a page that's still loading.
class SkeletonLines extends StatelessWidget {
  const SkeletonLines({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: FractionallySizedBox(widthFactor: const [0.7, 0.5, 0.6][i % 3], child: const SkeletonBox(height: 13)),
            ),
        ],
      ),
    );
  }
}

/// Feed posts on their way: author row, square picture, a line of text.
class SkeletonPosts extends StatelessWidget {
  const SkeletonPosts({super.key, this.count = 2});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Row(
                      children: [
                        SkeletonBox(width: 36, height: 36, radius: 18),
                        SizedBox(width: 10),
                        SkeletonBox(width: 120, height: 13),
                      ],
                    ),
                  ),
                  const AspectRatio(aspectRatio: 1, child: SkeletonBox(height: double.infinity, radius: 0)),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: FractionallySizedBox(widthFactor: 0.6, child: const SkeletonBox(height: 13)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
