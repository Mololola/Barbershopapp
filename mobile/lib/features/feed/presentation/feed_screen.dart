import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/loading.dart';
import '../../../core/status_message.dart';
import '../../auth/application/auth_controller.dart';
import '../application/feed_controller.dart';
import 'post_card.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    final myProfile = ref.watch(currentProfileProvider).value;
    final canPost = myProfile != null && !myProfile.isMinor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fresh Cuts'),
        centerTitle: false,
        titleSpacing: 20,
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: 'Leaderboards',
            onPressed: () => context.push('/rankings'),
          ),
        ],
      ),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => context.push('/posts/new'),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Post'),
            )
          : null,
      body: feed.when(
        loading: () => const LoadingView(caption: 'Fetching fresh cuts…'),
        error: (_, _) => Center(
          child: StatusMessage(
            icon: Icons.wifi_off_rounded,
            title: 'Couldn\'t load the feed',
            message: 'Check your connection and try again.',
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(feedProvider),
            isError: true,
          ),
        ),
        data: (feedState) {
          final posts = feedState.posts;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(feedProvider.future),
            child: posts.isEmpty
                // Scrollable so pull-to-refresh still works on an empty feed.
                ? LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: constraints.maxHeight,
                        child: Center(
                          child: StatusMessage(
                            icon: Icons.photo_camera_outlined,
                            title: 'The wall is empty',
                            message: 'Be the first to show off a cut.',
                            actionLabel: canPost ? 'Share a post' : null,
                            onAction: canPost ? () => context.push('/posts/new') : null,
                          ),
                        ),
                      ),
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    // Ask for the next page while about three screens (around
                    // five posts) are still left, so it's in before the end.
                    onNotification: (notification) {
                      final metrics = notification.metrics;
                      if (metrics.axis == Axis.vertical &&
                          metrics.extentAfter < metrics.viewportDimension * 3 &&
                          !feedState.loadMoreFailed) {
                        ref.read(feedProvider.notifier).loadMore();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      // Builds (and starts downloading photos for) the posts
                      // just below the screen before they scroll into view.
                      cacheExtent: MediaQuery.sizeOf(context).height * 1.5,
                      // Clear of the Post button at the end of the list.
                      padding: const EdgeInsets.only(top: 8, bottom: 88),
                      itemCount: posts.length + 1,
                      itemBuilder: (context, index) => Center(
                        // Portrait photos at a phone's width, even on the website.
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: index == posts.length
                              ? _FeedFooter(
                                  state: feedState,
                                  onRetry: () => ref.read(feedProvider.notifier).loadMore(),
                                )
                              : PostCard(post: posts[index], isMine: posts[index].authorId == myProfile?.id),
                        ),
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

/// The end of the loaded feed: the next page on its way, a retry if it
/// failed, or a sign-off once there's nothing older.
class _FeedFooter extends StatelessWidget {
  const _FeedFooter({required this.state, required this.onRetry});

  final FeedState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurface.withValues(alpha: 0.65);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: state.loadMoreFailed
            ? TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Couldn\'t load more posts. Try again'),
              )
            : state.hasMore
                ? const BarberPoleLoader(size: 24)
                : Column(
                    children: [
                      Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
                      const SizedBox(height: 8),
                      Text('You\'re all caught up', style: theme.textTheme.titleMedium),
                      Text('That\'s every post so far.', style: theme.textTheme.bodySmall?.copyWith(color: secondary)),
                    ],
                  ),
      ),
    );
  }
}
