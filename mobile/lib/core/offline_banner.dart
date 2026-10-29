import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n.dart';
import 'offline_cache.dart';
import 'theme.dart';

/// A strip along the bottom of every screen while there's no connection, so
/// it's clear the app is showing what it last saved.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectionProvider.select((c) => c.online));
    return Column(
      children: [
        Expanded(child: child),
        if (!online)
          Material(
            color: AppColors.charcoal,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.brass),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.offlineShowingSaved,
                        style: const TextStyle(color: AppColors.chalk, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
