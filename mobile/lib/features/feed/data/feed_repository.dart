import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/post.dart';

/// Posts/likes/comments are simple CRUD with no money/concurrency invariant,
/// so — like reviews — this writes directly to Supabase under RLS rather
/// than through FastAPI (see docs/architecture.md's client/backend split).
class FeedRepository {
  FeedRepository(this._client);

  final SupabaseClient _client;

  Future<List<Post>> fetchFeed({required String? myProfileId}) async {
    final rows = await _client
        .from('posts')
        .select('*, profiles(username), post_media(media_url), likes(profile_id), comments(count)')
        .order('created_at', ascending: false);
    return rows.map((row) => Post.fromRow(row, myProfileId: myProfileId)).toList();
  }

  Future<List<Comment>> fetchComments(String postId, {required String? myProfileId}) async {
    final rows = await _client
        .from('comments')
        .select('*, profiles(username), comment_likes(profile_id)')
        .eq('post_id', postId)
        .order('created_at');
    return rows.map((row) => Comment.fromRow(row, myProfileId: myProfileId)).toList();
  }

  Future<List<Post>> fetchPostsByAuthor({required String authorId, required String? myProfileId}) async {
    final rows = await _client
        .from('posts')
        .select('*, profiles(username), post_media(media_url), likes(profile_id), comments(count)')
        .eq('author_id', authorId)
        .order('created_at', ascending: false);
    return rows.map((row) => Post.fromRow(row, myProfileId: myProfileId)).toList();
  }

  Future<void> createPost({
    required String authorId,
    required String? body,
    required File? image,
  }) async {
    final post = await _client.from('posts').insert({'author_id': authorId, 'body': body}).select().single();

    if (image == null) return;
    // The post's own id is already a fresh unique value — no need to mint a
    // separate one just to name the file.
    final path = '$authorId/${post['id']}${_extensionOf(image.path)}';
    await _client.storage.from('post-media').upload(path, image);
    final mediaUrl = _client.storage.from('post-media').getPublicUrl(path);
    await _client.from('post_media').insert({'post_id': post['id'], 'media_url': mediaUrl});
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

  Future<void> deleteComment(String commentId) async {
    await _client.from('comments').delete().eq('id', commentId);
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    return dot == -1 ? '.jpg' : path.substring(dot);
  }
}
