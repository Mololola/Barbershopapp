class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  factory Message.fromRow(Map<String, dynamic> row) {
    return Message(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      senderId: row['sender_id'] as String,
      body: row['body'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      readAt: row['read_at'] != null ? DateTime.parse(row['read_at'] as String) : null,
    );
  }

  Map<String, dynamic> toRow() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'body': body,
        'created_at': createdAt.toIso8601String(),
        'read_at': readAt?.toIso8601String(),
      };
}
