import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_controller.dart';
import '../application/feed_controller.dart';
import '../domain/post.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  Comment? _replyingTo;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;
    final success = await ref.read(feedActionControllerProvider.notifier).addComment(
          postId: widget.postId,
          body: body,
          parentCommentId: _replyingTo?.id,
        );
    if (success) {
      _commentController.clear();
      setState(() => _replyingTo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(commentsProvider(widget.postId));
    final actionState = ref.watch(feedActionControllerProvider);
    final myProfile = ref.watch(currentProfileProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Comments')),
      body: Column(
        children: [
          Expanded(
            child: comments.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('No comments yet.'));
                }
                final topLevel = list.where((c) => c.parentCommentId == null);
                final repliesByParent = <String, List<Comment>>{};
                for (final comment in list) {
                  final parentId = comment.parentCommentId;
                  if (parentId != null) {
                    repliesByParent.putIfAbsent(parentId, () => []).add(comment);
                  }
                }
                return ListView(
                  children: [
                    for (final comment in topLevel) ...[
                      _CommentTile(
                        comment: comment,
                        myProfileId: myProfile?.id,
                        onReply: () => setState(() => _replyingTo = comment),
                      ),
                      for (final reply in repliesByParent[comment.id] ?? const <Comment>[])
                        Padding(
                          padding: const EdgeInsets.only(left: 32),
                          child: _CommentTile(comment: reply, myProfileId: myProfile?.id, onReply: null),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
          if (_replyingTo != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: Text('Replying to ${_replyingTo!.authorUsername}')),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(labelText: 'Add a comment'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: actionState.isLoading ? null : _submitComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends ConsumerWidget {
  const _CommentTile({required this.comment, required this.myProfileId, required this.onReply});

  final Comment comment;
  final String? myProfileId;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(feedActionControllerProvider);
    final isMine = comment.authorId == myProfileId;

    return ListTile(
      title: InkWell(
        onTap: () => context.push('/profile/${comment.authorId}'),
        child: Text(comment.authorUsername),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(comment.body),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  comment.likedByMe ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                ),
                color: comment.likedByMe ? Colors.red : null,
                onPressed: actionState.isLoading
                    ? null
                    : () => ref.read(feedActionControllerProvider.notifier).toggleCommentLike(
                          postId: comment.postId,
                          commentId: comment.id,
                          currentlyLiked: comment.likedByMe,
                        ),
              ),
              Text('${comment.likeCount}'),
              if (onReply != null)
                TextButton(
                  onPressed: onReply,
                  child: const Text('Reply'),
                ),
            ],
          ),
        ],
      ),
      trailing: isMine
          ? IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: actionState.isLoading
                  ? null
                  : () => ref
                      .read(feedActionControllerProvider.notifier)
                      .deleteComment(postId: comment.postId, commentId: comment.id),
            )
          : null,
    );
  }
}
