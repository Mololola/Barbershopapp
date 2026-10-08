enum PostMediaType { image, video }

class Post {
  const Post({
    required this.id,
    required this.authorId,
    required this.authorUsername,
    this.authorAvatarUrl,
    required this.body,
    required this.mediaUrl,
    required this.mediaType,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    required this.createdAt,
    required this.isPinned,
  });

  final String id;
  final String authorId;
  final String authorUsername;
  final String? authorAvatarUrl;
  final String? body;
  final String? mediaUrl;

  /// Only meaningful when [mediaUrl] is non-null.
  final PostMediaType mediaType;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final DateTime createdAt;

  /// Featured on the author's worker-candidate portfolio (see
  /// worker_candidate_detail_screen.dart) — separate from the chronological
  /// feed, a worker's own curated highlights.
  final bool isPinned;

  Post copyWith({int? likeCount, bool? likedByMe, bool? isPinned}) {
    return Post(
      id: id,
      authorId: authorId,
      authorUsername: authorUsername,
      authorAvatarUrl: authorAvatarUrl,
      body: body,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount,
      likedByMe: likedByMe ?? this.likedByMe,
      createdAt: createdAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  factory Post.fromRow(Map<String, dynamic> row, {required String? myProfileId}) {
    final media = row['post_media'] as List;
    final likes = row['likes'] as List;
    final comments = row['comments'] as List;
    final firstMedia = media.isEmpty ? null : media.first as Map<String, dynamic>;
    final author = row['profiles'] as Map<String, dynamic>;
    return Post(
      id: row['id'] as String,
      authorId: row['author_id'] as String,
      authorUsername: author['username'] as String,
      authorAvatarUrl: author['avatar_url'] as String?,
      body: row['body'] as String?,
      mediaUrl: firstMedia?['media_url'] as String?,
      mediaType: firstMedia?['media_type'] == 'video' ? PostMediaType.video : PostMediaType.image,
      likeCount: likes.length,
      commentCount: comments.isEmpty ? 0 : comments.first['count'] as int,
      likedByMe: myProfileId != null && likes.any((like) => like['profile_id'] == myProfileId),
      createdAt: DateTime.parse(row['created_at'] as String),
      isPinned: row['is_pinned'] as bool? ?? false,
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
    this.authorAvatarUrl,
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
  final String? authorAvatarUrl;
  final String body;
  final int likeCount;
  final bool likedByMe;
  final DateTime createdAt;

  Comment copyWith({int? likeCount, bool? likedByMe}) {
    return Comment(
      id: id,
      postId: postId,
      parentCommentId: parentCommentId,
      authorId: authorId,
      authorUsername: authorUsername,
      authorAvatarUrl: authorAvatarUrl,
      body: body,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      createdAt: createdAt,
    );
  }

  factory Comment.fromRow(Map<String, dynamic> row, {required String? myProfileId}) {
    final likes = row['comment_likes'] as List;
    final author = row['profiles'] as Map<String, dynamic>;
    return Comment(
      id: row['id'] as String,
      postId: row['post_id'] as String,
      parentCommentId: row['parent_comment_id'] as String?,
      authorId: row['author_id'] as String,
      authorUsername: author['username'] as String,
      authorAvatarUrl: author['avatar_url'] as String?,
      body: row['body'] as String,
      likeCount: likes.length,
      likedByMe: myProfileId != null && likes.any((like) => like['profile_id'] == myProfileId),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
