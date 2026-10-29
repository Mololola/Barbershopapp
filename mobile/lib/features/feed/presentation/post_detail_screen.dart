import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../core/loading.dart';
import '../../../core/status_message.dart';
import '../../auth/application/auth_controller.dart';
import '../../business/domain/brand.dart';
import '../application/feed_controller.dart';
import '../domain/post.dart';
import 'post_card.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _commentFocus = FocusNode();
  Comment? _replyingTo;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _replyTo(Comment comment) {
    setState(() => _replyingTo = comment);
    _commentFocus.requestFocus();
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
    final myProfile = ref.watch(currentProfileProvider).value;
    final canComment = myProfile?.isMinor != true;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.comments)),
      body: Column(
        children: [
          Expanded(
            child: comments.when(
              loading: () => LoadingView(caption: context.l10n.loadingComments),
              error: (_, _) => Center(
                child: StatusMessage(
                  icon: Icons.wifi_off_rounded,
                  title: context.l10n.couldntLoadComments,
                  message: context.l10n.checkConnection,
                  actionLabel: context.l10n.tryAgain,
                  onAction: () => ref.invalidate(commentsProvider(widget.postId)),
                  isError: true,
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: StatusMessage(
                      icon: Icons.chat_bubble_outline,
                      title: context.l10n.noCommentsYet,
                      message: canComment ? context.l10n.startConversation : context.l10n.commentsShowHere,
                      actionLabel: canComment ? context.l10n.writeAComment : null,
                      onAction: canComment ? _commentFocus.requestFocus : null,
                    ),
                  );
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                  children: [
                    for (final comment in topLevel) ...[
                      _CommentTile(
                        comment: comment,
                        myProfileId: myProfile?.id,
                        onReply: canComment ? () => _replyTo(comment) : null,
                      ),
                      for (final reply in repliesByParent[comment.id] ?? const <Comment>[])
                        Padding(
                          padding: const EdgeInsets.only(left: 44),
                          child: _CommentTile(comment: reply, myProfileId: myProfile?.id, onReply: null, isReply: true),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ),
          // No commenting on a minor account — see the guardian-consent design.
          if (canComment)
            _Composer(
              controller: _commentController,
              focusNode: _commentFocus,
              avatarUrl: myProfile?.avatarUrl,
              username: myProfile?.username ?? '',
              replyingTo: _replyingTo?.authorUsername,
              onCancelReply: () => setState(() => _replyingTo = null),
              onSend: _submitComment,
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.username, required this.url, required this.radius});

  final String username;
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primary.withValues(alpha: 0.12),
      foregroundColor: scheme.primary,
      backgroundImage: url != null ? NetworkImage(url!) : null,
      child: url == null
          ? Text(initialsOf(username), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.primary))
          : null,
    );
  }
}

class _CommentTile extends ConsumerStatefulWidget {
  const _CommentTile({required this.comment, required this.myProfileId, required this.onReply, this.isReply = false});

  final Comment comment;
  final String? myProfileId;
  final VoidCallback? onReply;
  final bool isReply;

  @override
  ConsumerState<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends ConsumerState<_CommentTile> {
  // Same optimistic-overlay pattern as PostCard's like button.
  late Comment _comment = widget.comment;
  bool _likeInFlight = false;

  @override
  void didUpdateWidget(_CommentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comment.id != widget.comment.id) _comment = widget.comment;
  }

  Future<void> _toggleLike() async {
    if (_likeInFlight) return;
    final before = _comment;
    setState(() {
      _comment = _comment.copyWith(
        likedByMe: !_comment.likedByMe,
        likeCount: _comment.likeCount + (_comment.likedByMe ? -1 : 1),
      );
      _likeInFlight = true;
    });
    final success = await ref
        .read(feedActionControllerProvider.notifier)
        .toggleCommentLike(commentId: before.id, currentlyLiked: before.likedByMe);
    if (!mounted) return;
    setState(() {
      _likeInFlight = false;
      if (!success) _comment = before;
    });
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.couldNotUpdateLike)));
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteCommentTitle),
        content: Text(context.l10n.cantBeUndone),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(feedActionControllerProvider.notifier)
          .deleteComment(postId: _comment.postId, commentId: _comment.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(feedActionControllerProvider);
    final comment = _comment;
    final isMine = comment.authorId == widget.myProfileId;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final secondary = scheme.onSurface.withValues(alpha: 0.65);
    final actionStyle = theme.textTheme.labelMedium?.copyWith(color: secondary, fontWeight: FontWeight.w600);
    final cardShape = theme.cardTheme.shape;
    final bubbleRadius = cardShape is RoundedRectangleBorder ? cardShape.borderRadius : BorderRadius.zero;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push('/profile/${comment.authorId}'),
            child: _Avatar(username: comment.authorUsername, url: comment.authorAvatarUrl, radius: widget.isReply ? 14 : 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Who said it on its own line, in bold, above what they said —
                // inside one bubble so each comment reads as a unit.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: BoxDecoration(
                    color: isMine ? scheme.primary.withValues(alpha: 0.08) : scheme.surface,
                    borderRadius: bubbleRadius,
                    border: Border.all(color: scheme.outline, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/profile/${comment.authorId}'),
                        child: Text(
                          comment.authorUsername,
                          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(comment.body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.35)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 0, 0),
                  child: Row(
                    children: [
                      Text(timeAgo(context.l10n, comment.createdAt), style: theme.textTheme.labelMedium?.copyWith(color: secondary)),
                      if (widget.onReply != null) ...[
                        const SizedBox(width: 16),
                        InkWell(onTap: widget.onReply, child: Text(context.l10n.reply, style: actionStyle)),
                      ],
                      if (isMine) ...[
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: actionState.isLoading ? null : _confirmDelete,
                          child: Text(context.l10n.delete, style: actionStyle),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 40,
            child: Column(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  tooltip: comment.likedByMe ? context.l10n.unlike : context.l10n.like,
                  icon: Icon(comment.likedByMe ? Icons.favorite : Icons.favorite_border),
                  color: comment.likedByMe ? scheme.secondary : secondary,
                  onPressed: _toggleLike,
                ),
                if (comment.likeCount > 0)
                  Text('${comment.likeCount}', style: theme.textTheme.labelSmall?.copyWith(color: secondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The comment box, pinned to the bottom: your avatar, the field, and a
/// send button that only lights up once there's something to send.
class _Composer extends ConsumerWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.avatarUrl,
    required this.username,
    required this.replyingTo,
    required this.onCancelReply,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? avatarUrl;
  final String username;
  final String? replyingTo;
  final VoidCallback onCancelReply;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sending = ref.watch(feedActionControllerProvider).isLoading;
    return Material(
      color: scheme.surface,
      shape: Border(top: BorderSide(color: scheme.outline)),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyingTo != null)
              Container(
                color: scheme.primary.withValues(alpha: 0.08),
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  children: [
                    Icon(Icons.reply, size: 16, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(context.l10n.replyingTo(replyingTo!), style: theme.textTheme.labelMedium)),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: context.l10n.cancelReply,
                      onPressed: onCancelReply,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  _Avatar(username: username, url: avatarUrl, radius: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: replyingTo != null ? context.l10n.writeAReply : context.l10n.addAComment,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      final ready = controller.text.trim().isNotEmpty && !sending;
                      return IconButton(
                        tooltip: context.l10n.send,
                        onPressed: ready ? onSend : null,
                        icon: Icon(Icons.send_rounded, color: ready ? scheme.primary : null),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
