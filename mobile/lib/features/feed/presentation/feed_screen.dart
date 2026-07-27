import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      appBar: AppBar(title: const Text('Feed')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/feed/new'),
        child: const Icon(Icons.add),
      ),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (posts) {
          if (posts.isEmpty) {
            return const Center(child: Text('No posts yet.'));
          }
          return ListView(
            children: [
              for (final post in posts) PostCard(post: post, isMine: post.authorId == myProfile?.id),
            ],
          );
        },
      ),
    );
  }
}
