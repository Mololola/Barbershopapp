import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/messaging_controller.dart';

/// Shared "Messages" entry point for both home screens — a plain button
/// with a small unread-count badge sourced from [conversationsProvider].
class MessagesEntryButton extends ConsumerWidget {
  const MessagesEntryButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider).value ?? [];
    final unreadCount = conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);

    return FilledButton(
      onPressed: () => context.push('/messages'),
      child: Text(unreadCount > 0 ? 'Messages ($unreadCount)' : 'Messages'),
    );
  }
}
