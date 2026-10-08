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
        data: (posts) => RefreshIndicator(
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
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  // Clear of the Post button at the end of the list.
                  padding: const EdgeInsets.only(top: 8, bottom: 88),
                  itemCount: posts.length,
                  itemBuilder: (context, index) => Center(
                    // Portrait photos at a phone's width, even on the website.
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: PostCard(post: posts[index], isMine: posts[index].authorId == myProfile?.id),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
