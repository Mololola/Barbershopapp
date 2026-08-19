import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/loading.dart';
import '../application/messaging_controller.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: conversations.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No conversations yet.'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final conversation = list[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      conversation.otherAvatarUrl != null ? NetworkImage(conversation.otherAvatarUrl!) : null,
                  child: conversation.otherAvatarUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Text(conversation.otherUsername),
                subtitle: conversation.lastMessageBody != null
                    ? Text(conversation.lastMessageBody!, maxLines: 1, overflow: TextOverflow.ellipsis)
                    : const Text('No messages yet'),
                trailing: conversation.unreadCount > 0
                    ? CircleAvatar(
                        radius: 12,
                        child: Text('${conversation.unreadCount}', style: const TextStyle(fontSize: 12)),
                      )
                    : null,
                onTap: () => context.push('/messages/${conversation.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
