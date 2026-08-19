import 'package:flutter/material.dart';

import 'theme.dart';

/// The app's one loading motif, used everywhere a screen would otherwise
/// show a bare spinner while its data is still in flight — a barber pole,
/// its stripes endlessly climbing, in the app's own charcoal/brass/chalk
/// rather than the classic red-white-blue so it reads as this app's loading
/// state and not a stock icon.
class BarberPoleLoader extends StatefulWidget {
  const BarberPoleLoader({super.key, this.size = 56});

  final double size;

  @override
  State<BarberPoleLoader> createState() => _BarberPoleLoaderState();
}

class _BarberPoleLoaderState extends State<BarberPoleLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 850))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size * 2.2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(painter: _BarberPolePainter(phase: _controller.value)),
      ),
    );
  }
}

class _BarberPolePainter extends CustomPainter {
  _BarberPolePainter({required this.phase});

  final double phase;

  static const _stripeColors = [AppColors.brass, AppColors.charcoal, AppColors.chalk];

  @override
  void paint(Canvas canvas, Size size) {
    final capHeight = size.width * 0.32;
    final tubeRect = Rect.fromLTWH(0, capHeight * 0.6, size.width, size.height - capHeight * 1.2);
    final tubeRRect = RRect.fromRectAndRadius(tubeRect, Radius.circular(size.width / 2));

    canvas.save();
    canvas.clipRRect(tubeRRect);
    canvas.drawRect(tubeRect, Paint()..color = AppColors.chalk);

    // Slanted bands, shifted downward each frame by `phase` (one stripe
    // period per animation cycle) — the classic barber-pole illusion of
    // stripes endlessly climbing.
    final stripeHeight = size.width * 0.55;
    final shear = size.width * 0.9;
    final offset = phase * stripeHeight;
    final start = -stripeHeight - shear;
    var i = 0;
    for (var y = start + offset; y < tubeRect.bottom + shear; y += stripeHeight) {
      final path = Path()
        ..moveTo(0, y)
        ..lineTo(size.width, y - shear)
        ..lineTo(size.width, y - shear + stripeHeight)
        ..lineTo(0, y + stripeHeight)
        ..close();
      canvas.drawPath(path, Paint()..color = _stripeColors[i % _stripeColors.length]);
      i++;
    }
    canvas.restore();

    final capPaint = Paint()..color = AppColors.brass;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, capHeight),
        Radius.circular(size.width / 2),
      ),
      capPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height - capHeight, size.width, capHeight),
        Radius.circular(size.width / 2),
      ),
      capPaint,
    );
  }

  @override
  bool shouldRepaint(_BarberPolePainter oldDelegate) => oldDelegate.phase != phase;
}

/// Drop-in replacement for `Center(child: CircularProgressIndicator())` in a
/// `.when(loading: ...)` branch, with an optional caption for screens where
/// a bare pole would look adrift.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.caption});

  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BarberPoleLoader(),
          if (caption != null) ...[
            const SizedBox(height: 12),
            Text(caption!, style: const TextStyle(color: AppColors.steel)),
          ],
        ],
      ),
    );
  }
}
