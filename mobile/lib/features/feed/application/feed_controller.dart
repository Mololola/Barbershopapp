import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/offline_cache.dart';
import '../../../core/error_reporting.dart';
import '../../../core/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/feed_repository.dart';
import '../domain/post.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(ref.watch(supabaseClientProvider), ref.watch(offlineCacheProvider));
});

/// A post is about a screen tall, so a page of ten is several screens of
/// scrolling — and the next page is requested well before the end (see
/// FeedScreen), so it's normally in before anyone gets there.
const feedPageSize = 10;

class FeedState {
  const FeedState({required this.posts, required this.hasMore, this.loadingMore = false, this.loadMoreFailed = false});

  final List<Post> posts;
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;
}

final feedProvider = AsyncNotifierProvider<FeedController, FeedState>(FeedController.new);

/// The feed, newest first, one page at a time.
class FeedController extends AsyncNotifier<FeedState> {
  @override
  Future<FeedState> build() async {
    final profile = await ref.watch(currentProfileProvider.future);
    final posts = await ref.watch(feedRepositoryProvider).fetchFeed(myProfileId: profile?.id, limit: feedPageSize);
    return FeedState(posts: posts, hasMore: posts.length == feedPageSize);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    final loading = FeedState(posts: current.posts, hasMore: true, loadingMore: true);
    state = AsyncData(loading);
    try {
      final profile = await ref.read(currentProfileProvider.future);
      final page = await ref
          .read(feedRepositoryProvider)
          .fetchFeed(myProfileId: profile?.id, before: current.posts.last.createdAt, limit: feedPageSize);
      // A pull-to-refresh while this page was loading has replaced the list.
      if (!ref.mounted || !identical(state.value, loading)) return;
      state = AsyncData(FeedState(posts: [...current.posts, ...page], hasMore: page.length == feedPageSize));
    } catch (error, stack) {
      reportError(error, stack, context: 'FeedController.loadMore');
      if (ref.mounted && identical(state.value, loading)) {
        state = AsyncData(FeedState(posts: current.posts, hasMore: true, loadMoreFailed: true));
      }
    }
  }

  /// Edits loaded posts in place, so an action elsewhere doesn't reload
  /// the feed and drop every page already scrolled through.
  void _update(Iterable<Post> Function(List<Post> posts) change) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(FeedState(
      posts: change(current.posts).toList(),
      hasMore: current.hasMore,
      loadingMore: current.loadingMore,
      loadMoreFailed: current.loadMoreFailed,
    ));
  }

  void remove(String postId) => _update((posts) => posts.where((p) => p.id != postId));

  void adjustCommentCount(String postId, int by) => _update(
        (posts) => posts.map((p) => p.id == postId ? p.copyWith(commentCount: p.commentCount + by) : p),
      );
}

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

  Future<bool> createPost({required String? body, required XFile? image, required XFile? video}) async {
    return _run(() async {
      final profile = await ref.read(currentProfileProvider.future);
      if (profile == null) throw StateError('No signed-in profile.');
      await ref.read(feedRepositoryProvider).createPost(authorId: profile.id, body: body, image: image, video: video);
      // The author's own list (their profile / a business's shop page),
      // and the feed from the top so the new post is first.
      ref.invalidate(postsByAuthorProvider(profile.id));
      ref.invalidate(feedProvider);
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
      if (ref.exists(feedProvider)) ref.read(feedProvider.notifier).adjustCommentCount(postId, 1);
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
      if (ref.exists(feedProvider)) ref.read(feedProvider.notifier).remove(postId);
    });
  }

  Future<bool> deleteComment({required String postId, required String commentId}) async {
    return _run(() async {
      await ref.read(feedRepositoryProvider).deleteComment(commentId);
      ref.invalidate(commentsProvider(postId));
      await ref.read(commentsProvider(postId).future);
      if (ref.exists(feedProvider)) ref.read(feedProvider.notifier).adjustCommentCount(postId, -1);
    });
  }

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      await action();
      success = true;
    });
    return success;
  }
}
