import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/loading.dart';
import '../application/messaging_controller.dart';
import '../domain/conversation.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Messages'),
          bottom: const TabBar(tabs: [Tab(text: 'Personal'), Tab(text: 'Business')]),
        ),
        body: conversations.when(
          loading: () => const LoadingView(),
          error: (error, _) => Center(child: Text('Error: $error')),
          data: (list) {
            final personal = list.where((c) => c.type == ConversationType.personal).toList();
            final business = list.where((c) => c.type == ConversationType.business).toList();
            return TabBarView(
              children: [
                _ConversationList(conversations: personal, emptyMessage: 'No personal messages yet.'),
                _ConversationList(conversations: business, emptyMessage: 'No business messages yet.'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({required this.conversations, required this.emptyMessage});

  final List<Conversation> conversations;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) {
      return Center(child: Text(emptyMessage));
    }
    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
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
  }
}
