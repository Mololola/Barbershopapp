class Post {
  const Post({
    required this.id,
    required this.authorId,
    required this.authorUsername,
    required this.body,
    required this.mediaUrl,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorUsername;
  final String? body;
  final String? mediaUrl;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final DateTime createdAt;

  factory Post.fromRow(Map<String, dynamic> row, {required String? myProfileId}) {
    final media = row['post_media'] as List;
    final likes = row['likes'] as List;
    final comments = row['comments'] as List;
    return Post(
      id: row['id'] as String,
      authorId: row['author_id'] as String,
      authorUsername: (row['profiles'] as Map<String, dynamic>)['username'] as String,
      body: row['body'] as String?,
      mediaUrl: media.isEmpty ? null : media.first['media_url'] as String,
      likeCount: likes.length,
      commentCount: comments.isEmpty ? 0 : comments.first['count'] as int,
      likedByMe: myProfileId != null && likes.any((like) => like['profile_id'] == myProfileId),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}

class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.parentCommentId,
    required this.authorId,
    required this.authorUsername,
    required this.body,
    required this.likeCount,
    required this.likedByMe,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String? parentCommentId;
  final String authorId;
  final String authorUsername;
  final String body;
  final int likeCount;
  final bool likedByMe;
  final DateTime createdAt;

  factory Comment.fromRow(Map<String, dynamic> row, {required String? myProfileId}) {
    final likes = row['comment_likes'] as List;
    return Comment(
      id: row['id'] as String,
      postId: row['post_id'] as String,
      parentCommentId: row['parent_comment_id'] as String?,
      authorId: row['author_id'] as String,
      authorUsername: (row['profiles'] as Map<String, dynamic>)['username'] as String,
      body: row['body'] as String,
      likeCount: likes.length,
      likedByMe: myProfileId != null && likes.any((like) => like['profile_id'] == myProfileId),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
