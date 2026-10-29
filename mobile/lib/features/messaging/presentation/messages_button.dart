import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../auth/application/auth_controller.dart';
import '../application/messaging_controller.dart';

/// Top-right app-bar entry to Messages, badged with how many chats have
/// unread messages ("9+" past nine). Renders nothing for a minor account,
/// which can't use direct messages (see the guardian-consent design).
class MessagesButton extends ConsumerWidget {
  const MessagesButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentProfileProvider).value?.isMinor == true) return const SizedBox.shrink();
    final conversations = ref.watch(conversationsProvider).value ?? const [];
    final unreadChats = conversations.where((c) => c.unreadCount > 0).length;
    return IconButton(
      tooltip: unreadChats == 0 ? context.l10n.navMessages : context.l10n.messagesUnreadTooltip(unreadChats),
      onPressed: () => context.push('/messages'),
      icon: Badge(
        isLabelVisible: unreadChats > 0,
        label: Text(unreadChats > 9 ? '9+' : '$unreadChats'),
        child: const Icon(Icons.mode_comment_outlined),
      ),
    );
  }
}
