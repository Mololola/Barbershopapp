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

  /// Every conversation I'm in, in one request: the *other* participant's
  /// profile (PostgREST needs an explicit FK hint since `conversations` has
  /// two FKs to `profiles`), only the latest message for the preview, and
  /// the unread count counted on the server — never the whole message
  /// history.
  Future<List<Conversation>> fetchConversations(String myId) async {
    final rows = await _client
        .from('conversations')
        .select(
          'id, participant_a_id, participant_b_id, type, '
          'participant_a:profiles!conversations_participant_a_id_fkey(username, avatar_url), '
          'participant_b:profiles!conversations_participant_b_id_fkey(username, avatar_url), '
          'last_message:messages(body, created_at), unread:messages(count)',
        )
        .or('participant_a_id.eq.$myId,participant_b_id.eq.$myId')
        .isFilter('unread.read_at', null)
        .neq('unread.sender_id', myId)
        .order('created_at', ascending: false, referencedTable: 'last_message')
        .limit(1, referencedTable: 'last_message');

    final conversations = rows.map((row) {
      final id = row['id'] as String;
      final isParticipantA = row['participant_a_id'] as String == myId;
      final otherProfile =
          (isParticipantA ? row['participant_b'] : row['participant_a']) as Map<String, dynamic>;
      final otherId =
          (isParticipantA ? row['participant_b_id'] : row['participant_a_id']) as String;
      final lastMessages = row['last_message'] as List;
      final lastMessage = lastMessages.isEmpty ? null : lastMessages.first as Map<String, dynamic>;
      final unread = row['unread'] as List;

      return Conversation(
        id: id,
        otherParticipantId: otherId,
        otherUsername: otherProfile['username'] as String,
        otherAvatarUrl: otherProfile['avatar_url'] as String?,
        lastMessageBody: lastMessage?['body'] as String?,
        lastMessageAt: lastMessage == null ? null : DateTime.parse(lastMessage['created_at'] as String),
        unreadCount: unread.isEmpty ? 0 : unread.first['count'] as int,
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
