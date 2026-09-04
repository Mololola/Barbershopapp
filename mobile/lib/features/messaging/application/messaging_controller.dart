import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/messaging_repository.dart';
import '../domain/conversation.dart';
import '../domain/message.dart';

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  return MessagingRepository(ref.watch(supabaseClientProvider));
});

/// autoDispose — an inbox is stale the moment the other side of any
/// conversation sends a message, matching the same reasoning as rankings
/// and the worker marketplace: re-fetch every time the screen is opened.
final conversationsProvider = FutureProvider.autoDispose<List<Conversation>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.watch(messagingRepositoryProvider).fetchConversations(profile.id);
});

/// Looked up from the already-fetched inbox rather than a dedicated query —
/// used by ConversationScreen to know who it's showing a thread with (e.g.
/// to match a business's pending leave requests against the other
/// participant).
final conversationByIdProvider = Provider.family<Conversation?, String>((ref, conversationId) {
  final conversations = ref.watch(conversationsProvider).value ?? const [];
  return conversations.where((c) => c.id == conversationId).firstOrNull;
});

/// Fetches message history, then appends each Realtime INSERT for this
/// conversation as it arrives — including the sender's own messages, so
/// sending doesn't need separate optimistic-append logic; the subscription
/// delivers it back once committed. The channel is torn down on dispose,
/// which happens automatically once the conversation screen is left.
final conversationMessagesProvider =
    StreamProvider.autoDispose.family<List<Message>, String>((ref, conversationId) {
  final client = ref.watch(supabaseClientProvider);
  final repository = ref.watch(messagingRepositoryProvider);
  final controller = StreamController<List<Message>>();
  var messages = <Message>[];

  repository.fetchMessages(conversationId).then((initial) {
    messages = initial;
    if (!controller.isClosed) controller.add(messages);
  }).catchError((Object error, StackTrace stackTrace) {
    if (!controller.isClosed) controller.addError(error, stackTrace);
  });

  final channel = client.channel('messages:$conversationId').onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: (payload) {
          messages = [...messages, Message.fromRow(payload.newRecord)];
          if (!controller.isClosed) controller.add(messages);
        },
      );
  channel.subscribe();

  ref.onDispose(() {
    client.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});

final messagingActionControllerProvider =
    AsyncNotifierProvider<MessagingActionController, void>(MessagingActionController.new);

class MessagingActionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String> startOrGetConversation(
    String otherProfileId, {
    ConversationType type = ConversationType.personal,
  }) async {
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null) throw StateError('Not signed in.');
    return ref
        .read(messagingRepositoryProvider)
        .startOrGetConversation(profile.id, otherProfileId, type: type);
  }

  Future<void> sendMessage(String conversationId, String body) async {
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null) throw StateError('Not signed in.');
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(messagingRepositoryProvider).sendMessage(conversationId, profile.id, body);
    });
  }

  Future<void> markConversationRead(String conversationId) async {
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null) return;
    await ref.read(messagingRepositoryProvider).markConversationRead(conversationId, profile.id);
    ref.invalidate(conversationsProvider);
  }
}
