import 'package:flutter/material.dart';

import 'theme.dart';

/// A network image that fades in once loaded instead of popping in on
/// whatever frame the bytes happen to land, and shows a plain broken-image
/// state instead of a raw exception if the fetch fails.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage(this.url, {super.key, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(color: AppColors.divider.withValues(alpha: 0.3));
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppColors.divider.withValues(alpha: 0.3),
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, color: AppColors.steel),
      ),
    );
  }
}
