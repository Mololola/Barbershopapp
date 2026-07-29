class Conversation {
  const Conversation({
    required this.id,
    required this.otherParticipantId,
    required this.otherUsername,
    this.otherAvatarUrl,
    this.lastMessageBody,
    this.lastMessageAt,
    required this.unreadCount,
  });

  final String id;
  final String otherParticipantId;
  final String otherUsername;
  final String? otherAvatarUrl;
  final String? lastMessageBody;
  final DateTime? lastMessageAt;
  final int unreadCount;
}
