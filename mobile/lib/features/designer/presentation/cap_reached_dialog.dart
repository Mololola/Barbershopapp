import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/designer_controller.dart';

Future<void> showCapReachedDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Design limit reached'),
      content: Text(
        'You can save up to $maxFreeDesigns designs for free. Delete one to make room, '
        'or buy +2 more slots for £2.00 — buy again any time you fill up.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            Navigator.pop(context);
            try {
              final url = await ref.read(designEditControllerProvider.notifier).startExtraSlotsCheckout();
              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
              }
            }
          },
          child: const Text('Buy +2 slots (£2.00)'),
        ),
      ],
    ),
  );
}
