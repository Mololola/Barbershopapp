import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error_reporting.dart';
import '../../../core/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/feed_repository.dart';
import '../domain/post.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(ref.watch(supabaseClientProvider));
});

final feedProvider = FutureProvider<List<Post>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  return ref.watch(feedRepositoryProvider).fetchFeed(myProfileId: profile?.id);
});

final commentsProvider = FutureProvider.family<List<Comment>, String>((ref, postId) async {
  final profile = await ref.watch(currentProfileProvider.future);
  return ref.watch(feedRepositoryProvider).fetchComments(postId, myProfileId: profile?.id);
});

final postsByAuthorProvider = FutureProvider.family<List<Post>, String>((ref, authorId) async {
  final profile = await ref.watch(currentProfileProvider.future);
  return ref.watch(feedRepositoryProvider).fetchPostsByAuthor(authorId: authorId, myProfileId: profile?.id);
});

/// The worker-candidate detail screen's portfolio grid — a curated subset of
/// [postsByAuthorProvider], not the full chronological feed.
final pinnedPostsProvider = FutureProvider.family<List<Post>, String>((ref, authorId) async {
  return ref.watch(feedRepositoryProvider).fetchPinnedPosts(authorId);
});

final feedActionControllerProvider = AsyncNotifierProvider<FeedActionController, void>(FeedActionController.new);

class FeedActionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> createPost({required String? body, required File? image, required File? video}) async {
    return _run(() async {
      final profile = await ref.read(currentProfileProvider.future);
      if (profile == null) throw StateError('No signed-in profile.');
      await ref.read(feedRepositoryProvider).createPost(authorId: profile.id, body: body, image: image, video: video);
    });
  }

  // Unlike the other actions below, a like toggle doesn't touch the shared
  // `state` or refetch the list — PostCard/_CommentTile show the new state
  // immediately themselves (optimistic UI) and revert on failure, so
  // there's nothing here that should disable every other post's buttons or
  // force a full-list reload for what's ultimately a one-row flip.
  Future<bool> toggleLike({required String postId, required bool currentlyLiked}) async {
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null) return false;
    try {
      await ref
          .read(feedRepositoryProvider)
          .toggleLike(postId: postId, profileId: profile.id, currentlyLiked: currentlyLiked);
      return true;
    } catch (error, stack) {
      reportError(error, stack, context: 'FeedActionController.toggleLike');
      return false;
    }
  }

  Future<bool> addComment({required String postId, required String body, String? parentCommentId}) async {
    return _run(() async {
      final profile = await ref.read(currentProfileProvider.future);
      if (profile == null) throw StateError('No signed-in profile.');
      await ref.read(feedRepositoryProvider).addComment(
            postId: postId,
            authorId: profile.id,
            body: body,
            parentCommentId: parentCommentId,
          );
      ref.invalidate(commentsProvider(postId));
      await ref.read(commentsProvider(postId).future);
    });
  }

  Future<bool> toggleCommentLike({
    required String commentId,
    required bool currentlyLiked,
  }) async {
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null) return false;
    try {
      await ref.read(feedRepositoryProvider).toggleCommentLike(
            commentId: commentId,
            profileId: profile.id,
            currentlyLiked: currentlyLiked,
          );
      return true;
    } catch (error, stack) {
      reportError(error, stack, context: 'FeedActionController.toggleCommentLike');
      return false;
    }
  }

  // Same reasoning as toggleLike: an instant, per-post optimistic flip, not
  // a global-state action that disables every other post's buttons.
  Future<bool> togglePin({required String postId, required bool currentlyPinned}) async {
    try {
      await ref.read(feedRepositoryProvider).togglePin(postId: postId, currentlyPinned: currentlyPinned);
      return true;
    } catch (error, stack) {
      reportError(error, stack, context: 'FeedActionController.togglePin');
      return false;
    }
  }

  Future<bool> deletePost(String postId) async {
    return _run(() async {
      await ref.read(feedRepositoryProvider).deletePost(postId);
    });
  }

  Future<bool> deleteComment({required String postId, required String commentId}) async {
    return _run(() async {
      await ref.read(feedRepositoryProvider).deleteComment(commentId);
      ref.invalidate(commentsProvider(postId));
      await ref.read(commentsProvider(postId).future);
    });
  }

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await action();
      ref.invalidate(feedProvider);
      await ref.read(feedProvider.future);
      success = true;
    });
    return success;
  }
}
