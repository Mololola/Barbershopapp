import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/feed_controller.dart';
import '../domain/post.dart';

/// Shared between the feed and a profile's own-posts list.
class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post, required this.isMine});

  final Post post;
  final bool isMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(feedActionControllerProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: InkWell(
              onTap: () => context.push('/profile/${post.authorId}'),
              child: Text(post.authorUsername),
            ),
            trailing: isMine
                ? IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: actionState.isLoading
                        ? null
                        : () => ref.read(feedActionControllerProvider.notifier).deletePost(post.id),
                  )
                : null,
          ),
          if (post.mediaUrl != null)
            Image.network(post.mediaUrl!, fit: BoxFit.contain, width: double.infinity, height: 320),
          if (post.body != null && post.body!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(post.body!),
            ),
          Row(
            children: [
              IconButton(
                icon: Icon(post.likedByMe ? Icons.favorite : Icons.favorite_border),
                color: post.likedByMe ? Colors.red : null,
                onPressed: actionState.isLoading
                    ? null
                    : () => ref
                        .read(feedActionControllerProvider.notifier)
                        .toggleLike(postId: post.id, currentlyLiked: post.likedByMe),
              ),
              Text('${post.likeCount}'),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.mode_comment_outlined),
                onPressed: () => context.push('/feed/${post.id}'),
              ),
              Text('${post.commentCount}'),
            ],
          ),
        ],
      ),
    );
  }
}
