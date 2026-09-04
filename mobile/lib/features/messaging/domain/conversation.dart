enum ConversationType { personal, business }

extension ConversationTypeX on ConversationType {
  String get wireValue => name;

  static ConversationType fromWireValue(String value) {
    return ConversationType.values.firstWhere((type) => type.wireValue == value);
  }
}

class Conversation {
  const Conversation({
    required this.id,
    required this.otherParticipantId,
    required this.otherUsername,
    this.otherAvatarUrl,
    this.lastMessageBody,
    this.lastMessageAt,
    required this.unreadCount,
    required this.type,
  });

  final String id;
  final String otherParticipantId;
  final String otherUsername;
  final String? otherAvatarUrl;
  final String? lastMessageBody;
  final DateTime? lastMessageAt;
  final int unreadCount;

  /// 'business' for a shop reaching out about work (marketplace messaging,
  /// leave-request system messages) — kept in a separate inbox from
  /// 'personal' threads. See conversations_screen.dart.
  final ConversationType type;
}
