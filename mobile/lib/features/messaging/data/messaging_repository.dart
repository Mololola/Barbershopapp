import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/conversation.dart';
import '../domain/message.dart';

class MessagingRepository {
  MessagingRepository(this._client);

  final SupabaseClient _client;

  /// Sorting the pair before upsert (matched by the migration's `check
  /// (participant_a_id < participant_b_id)` + unique constraint) means this
  /// is safe to call from either side — it returns the same conversation
  /// whether it already existed or was just created. `type` is part of the
  /// conflict key, so the same two people can hold both a personal and a
  /// business thread at once (see the migration).
  Future<String> startOrGetConversation(
    String myId,
    String otherId, {
    ConversationType type = ConversationType.personal,
  }) async {
    final ids = [myId, otherId]..sort();
    final rows = await _client
        .from('conversations')
        .upsert(
          {'participant_a_id': ids[0], 'participant_b_id': ids[1], 'type': type.wireValue},
          onConflict: 'participant_a_id,participant_b_id,type',
        )
        .select();
    return rows.first['id'] as String;
  }

  /// Fetches every conversation I'm in, joined to the *other* participant's
  /// profile (PostgREST needs an explicit FK hint since `conversations` has
  /// two FKs to `profiles`), then a second query for all messages in those
  /// conversations to derive the last-message preview and unread count in
  /// Dart. Simple and fine at this app's scale — see finance_calculator.dart
  /// for the same "compute in Dart" style; revisit with a view/RPC if the
  /// message table grows large.
  Future<List<Conversation>> fetchConversations(String myId) async {
    final rows = await _client
        .from('conversations')
        .select(
          'id, participant_a_id, participant_b_id, type, '
          'participant_a:profiles!conversations_participant_a_id_fkey(username, avatar_url), '
          'participant_b:profiles!conversations_participant_b_id_fkey(username, avatar_url)',
        )
        .or('participant_a_id.eq.$myId,participant_b_id.eq.$myId');

    final conversationIds = rows.map((row) => row['id'] as String).toList();
    final messageRows = conversationIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
            .from('messages')
            .select()
            .inFilter('conversation_id', conversationIds)
            .order('created_at', ascending: true);
    final messages = messageRows.map(Message.fromRow).toList();

    final messagesByConversation = <String, List<Message>>{};
    for (final message in messages) {
      (messagesByConversation[message.conversationId] ??= []).add(message);
    }

    final conversations = rows.map((row) {
      final id = row['id'] as String;
      final isParticipantA = row['participant_a_id'] as String == myId;
      final otherProfile =
          (isParticipantA ? row['participant_b'] : row['participant_a']) as Map<String, dynamic>;
      final otherId =
          (isParticipantA ? row['participant_b_id'] : row['participant_a_id']) as String;
      final conversationMessages = messagesByConversation[id] ?? [];
      final lastMessage = conversationMessages.isEmpty ? null : conversationMessages.last;
      final unreadCount =
          conversationMessages.where((m) => m.senderId != myId && m.readAt == null).length;

      return Conversation(
        id: id,
        otherParticipantId: otherId,
        otherUsername: otherProfile['username'] as String,
        otherAvatarUrl: otherProfile['avatar_url'] as String?,
        lastMessageBody: lastMessage?.body,
        lastMessageAt: lastMessage?.createdAt,
        unreadCount: unreadCount,
        type: ConversationTypeX.fromWireValue(row['type'] as String),
      );
    }).toList();

    conversations.sort((a, b) {
      final aTime = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return conversations;
  }

  Future<List<Message>> fetchMessages(String conversationId) async {
    final rows = await _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
    return rows.map(Message.fromRow).toList();
  }

  Future<void> sendMessage(String conversationId, String senderId, String body) async {
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': senderId,
      'body': body,
    });
  }

  Future<void> markConversationRead(String conversationId, String myId) async {
    await _client
        .from('messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('conversation_id', conversationId)
        .neq('sender_id', myId)
        .isFilter('read_at', null);
  }
}
