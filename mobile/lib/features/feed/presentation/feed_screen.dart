import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/loading.dart';
import '../../../core/theme.dart';
import '../../auth/application/auth_controller.dart';
import '../application/feed_controller.dart';
import 'post_card.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    final myProfile = ref.watch(currentProfileProvider).value;

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
      floatingActionButton: myProfile?.isMinor == true
          ? null
          : FloatingActionButton(
              heroTag: null,
              onPressed: () => context.push('/posts/new'),
              child: const Icon(Icons.add),
            ),
      body: feed.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (posts) {
          if (posts.isEmpty) {
            return _EmptyFeed(onCreate: () => context.push('/posts/new'));
          }
          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            children: [
              for (final post in posts) PostCard(post: post, isMine: post.authorId == myProfile?.id),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_camera_outlined, color: AppColors.brass, size: 40),
            const SizedBox(height: 12),
            Text('The wall is empty', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Be the first to show off a cut.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.steel),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Share a post'),
            ),
          ],
        ),
      ),
    );
  }
}
