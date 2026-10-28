import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/picked_media.dart';
import '../domain/post.dart';

/// Posts/likes/comments are simple CRUD with no money/concurrency invariant,
/// so — like reviews — this writes directly to Supabase under RLS rather
/// than through FastAPI (see docs/architecture.md's client/backend split).
class FeedRepository {
  FeedRepository(this._client);

  final SupabaseClient _client;

  /// Like counts are counted on the server; of the likes themselves only
  /// mine comes back (filtered below), which is all `likedByMe` needs.
  static const _postColumns = '*, profiles(username, avatar_url), post_media(media_url, media_type), '
      'like_count:likes(count), my_like:likes(profile_id), comments(count)';

  PostgrestFilterBuilder<PostgrestList> _posts(String? myProfileId) {
    final query = _client.from('posts').select(_postColumns);
    return myProfileId == null ? query : query.eq('my_like.profile_id', myProfileId);
  }

  /// One page of the feed, newest first: the [limit] posts older than
  /// [before] (the oldest post already shown), or the newest when null.
  Future<List<Post>> fetchFeed({required String? myProfileId, DateTime? before, required int limit}) async {
    var query = _posts(myProfileId);
    if (before != null) query = query.lt('created_at', before.toUtc().toIso8601String());
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return rows.map((row) => Post.fromRow(row, myProfileId: myProfileId)).toList();
  }

  Future<List<Comment>> fetchComments(String postId, {required String? myProfileId}) async {
    final rows = await _client
        .from('comments')
        .select('*, profiles(username, avatar_url), comment_likes(profile_id)')
        .eq('post_id', postId)
        .order('created_at');
    return rows.map((row) => Comment.fromRow(row, myProfileId: myProfileId)).toList();
  }

  Future<List<Post>> fetchPostsByAuthor({required String authorId, required String? myProfileId}) async {
    final rows = await _posts(myProfileId)
        .eq('author_id', authorId)
        .order('created_at', ascending: false);
    return rows.map((row) => Post.fromRow(row, myProfileId: myProfileId)).toList();
  }

  Future<void> createPost({
    required String authorId,
    required String? body,
    required XFile? image,
    required XFile? video,
  }) async {
    assert(image == null || video == null, 'A post has at most one piece of media — an image or a video, not both.');
    final post = await _client.from('posts').insert({'author_id': authorId, 'body': body}).select().single();

    final mediaFile = image ?? video;
    if (mediaFile == null) return;
    final mediaType = video != null ? 'video' : 'image';

    // The post's own id is already a fresh unique value — no need to mint a
    // separate one just to name the file. Content type is set explicitly
    // (not left to the client library's guess) since the post-media
    // bucket enforces allowed_mime_types.
    final extension = extensionOf(mediaFile);
    final path = '$authorId/${post['id']}$extension';
    await _client.storage.from('post-media').uploadBinary(
          path,
          await uploadBytes(mediaFile),
          fileOptions: FileOptions(contentType: _contentTypeOf(extension)),
        );
    final mediaUrl = _client.storage.from('post-media').getPublicUrl(path);
    await _client.from('post_media').insert({'post_id': post['id'], 'media_url': mediaUrl, 'media_type': mediaType});
  }

  Future<void> toggleLike({required String postId, required String profileId, required bool currentlyLiked}) async {
    if (currentlyLiked) {
      await _client.from('likes').delete().eq('post_id', postId).eq('profile_id', profileId);
      return;
    }
    try {
      await _client.from('likes').insert({'post_id': postId, 'profile_id': profileId});
    } on PostgrestException catch (e) {
      // Already liked (e.g. a duplicate tap before the UI caught up) — the
      // end state the caller wants already holds, so treat it as a no-op.
      if (e.code != '23505') rethrow;
    }
  }

  Future<void> addComment({
    required String postId,
    required String authorId,
    required String body,
    String? parentCommentId,
  }) async {
    await _client.from('comments').insert({
      'post_id': postId,
      'author_id': authorId,
      'body': body,
      if (parentCommentId != null) 'parent_comment_id': parentCommentId,
    });
  }

  Future<void> toggleCommentLike({
    required String commentId,
    required String profileId,
    required bool currentlyLiked,
  }) async {
    if (currentlyLiked) {
      await _client.from('comment_likes').delete().eq('comment_id', commentId).eq('profile_id', profileId);
      return;
    }
    try {
      await _client.from('comment_likes').insert({'comment_id': commentId, 'profile_id': profileId});
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
  }

  Future<void> deletePost(String postId) async {
    await _client.from('posts').delete().eq('id', postId);
  }

  /// Portfolio posts on the marketplace candidate detail view — see
  /// WorkerCandidateDetailScreen.
  Future<List<Post>> fetchPinnedPosts(String authorId) async {
    final rows = await _posts(authorId)
        .eq('author_id', authorId)
        .eq('is_pinned', true)
        .order('created_at', ascending: false);
    return rows.map((row) => Post.fromRow(row, myProfileId: authorId)).toList();
  }

  Future<void> togglePin({required String postId, required bool currentlyPinned}) async {
    await _client.from('posts').update({'is_pinned': !currentlyPinned}).eq('id', postId);
  }

  Future<void> deleteComment(String commentId) async {
    await _client.from('comments').delete().eq('id', commentId);
  }

  /// Must match one of post-media's allowed_mime_types (see the
  /// d7f3a92c1e58 migration) or Supabase rejects the upload.
  String _contentTypeOf(String extension) {
    switch (extension.toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.jpg':
      case '.jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
