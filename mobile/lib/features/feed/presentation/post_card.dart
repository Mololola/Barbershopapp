import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../../core/app_network_image.dart';
import '../../../core/l10n.dart';
import '../../../core/loading.dart';
import '../../auth/application/auth_controller.dart';
import '../../business/domain/brand.dart';
import '../application/feed_controller.dart';
import '../domain/post.dart';

/// Shared between the feed and a profile's own-posts list.
class PostCard extends ConsumerStatefulWidget {
  const PostCard({super.key, required this.post, required this.isMine});

  final Post post;
  final bool isMine;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  // Optimistic overlay on top of widget.post — flipped immediately on tap
  // and reconciled with the server in the background, rather than the
  // button sitting disabled for a round trip to flip one boolean.
  late Post _post = widget.post;
  bool _likeInFlight = false;
  bool _showHeart = false;

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _post = widget.post;
    } else if (oldWidget.post != widget.post) {
      // Fresh counts from the feed (e.g. a new comment), keeping a like or
      // pin just toggled here that the feed's copy doesn't know about.
      _post = widget.post.copyWith(likedByMe: _post.likedByMe, likeCount: _post.likeCount, isPinned: _post.isPinned);
    }
  }

  Future<void> _toggleLike() async {
    if (_likeInFlight) return;
    final before = _post;
    setState(() {
      _post = _post.copyWith(
        likedByMe: !_post.likedByMe,
        likeCount: _post.likeCount + (_post.likedByMe ? -1 : 1),
      );
      _likeInFlight = true;
    });
    final success = await ref
        .read(feedActionControllerProvider.notifier)
        .toggleLike(postId: before.id, currentlyLiked: before.likedByMe);
    if (!mounted) return;
    setState(() {
      _likeInFlight = false;
      if (!success) _post = before;
    });
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.couldNotUpdateLike)));
    }
  }

  Future<void> _togglePin() async {
    final before = _post;
    setState(() => _post = _post.copyWith(isPinned: !_post.isPinned));
    final success = await ref
        .read(feedActionControllerProvider.notifier)
        .togglePin(postId: before.id, currentlyPinned: before.isPinned);
    if (!mounted) return;
    if (!success) {
      setState(() => _post = before);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.couldNotUpdatePortfolio)));
    }
  }

  /// Double-tapping a photo only ever likes (never unlikes), with a heart
  /// that pops over it either way — the feed's small moment of delight.
  void _likeByDoubleTap() {
    if (!_post.likedByMe) _toggleLike();
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deletePostTitle),
        content: Text(context.l10n.deletePostBody),
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
    if (confirmed == true) await ref.read(feedActionControllerProvider.notifier).deletePost(_post.id);
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(feedActionControllerProvider);
    final post = _post;
    final isMinor = ref.watch(currentProfileProvider).value?.isMinor == true;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final secondary = scheme.onSurface.withValues(alpha: 0.65);
    final hasBody = post.body != null && post.body!.isNotEmpty;

    // Flat, like a photo feed: no card around the post, the photo runs edge
    // to edge, and the chrome around it stays slim.
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/profile/${post.authorId}'),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: scheme.primary.withValues(alpha: 0.12),
                            foregroundColor: scheme.primary,
                            backgroundImage: post.authorAvatarUrl != null ? NetworkImage(post.authorAvatarUrl!) : null,
                            child: post.authorAvatarUrl == null
                                ? Text(initialsOf(post.authorUsername), style: theme.textTheme.labelSmall)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              post.authorUsername,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(' · ${timeAgo(context.l10n, post.createdAt)}', style: theme.textTheme.bodySmall?.copyWith(color: secondary)),
                          if (widget.isMine && post.isPinned) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.push_pin, size: 14, color: scheme.primary, semanticLabel: context.l10n.inPortfolio),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.isMine)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz),
                    tooltip: context.l10n.postOptions,
                    enabled: !actionState.isLoading,
                    onSelected: (action) => action == 'pin' ? _togglePin() : _confirmDelete(),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'pin',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(post.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                          title: Text(post.isPinned ? context.l10n.removeFromPortfolio : context.l10n.addToPortfolio),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete_outline, color: scheme.error),
                          title: Text(context.l10n.delete, style: TextStyle(color: scheme.error)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (post.mediaUrl != null && post.mediaType == PostMediaType.video)
            _PostVideoPlayer(url: post.mediaUrl!)
          else if (post.mediaUrl != null)
            GestureDetector(
              onDoubleTap: isMinor ? null : _likeByDoubleTap,
              child: AspectRatio(
                aspectRatio: _mediaAspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppNetworkImage(post.mediaUrl!),
                    Center(
                      child: AnimatedScale(
                        scale: _showHeart ? 1 : 0.4,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutBack,
                        child: AnimatedOpacity(
                          opacity: _showHeart ? 1 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.favorite, size: 96, color: scheme.surface),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // A text-only post is the text itself, so it comes before the actions.
          if (hasBody && post.mediaUrl == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Text(post.body!, style: theme.textTheme.titleMedium?.copyWith(height: 1.4)),
            ),
          Row(
            children: [
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    post.likedByMe ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey(post.likedByMe),
                    color: post.likedByMe ? scheme.secondary : null,
                  ),
                ),
                tooltip: post.likedByMe ? context.l10n.unlike : context.l10n.like,
                onPressed: isMinor ? null : _toggleLike,
              ),
              IconButton(
                icon: const Icon(Icons.mode_comment_outlined),
                tooltip: context.l10n.comments,
                onPressed: () => context.push('/posts/${post.id}'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.likeCount > 0)
                  Text(
                    context.l10n.likeCount(post.likeCount),
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                if (hasBody && post.mediaUrl != null) ...[
                  const SizedBox(height: 4),
                  // Two lines in the feed; the whole caption is on the post.
                  GestureDetector(
                    onTap: () => context.push('/posts/${post.id}'),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${post.authorUsername} ', style: const TextStyle(fontWeight: FontWeight.w600)),
                          TextSpan(text: post.body),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
                if (post.commentCount > 0)
                  InkWell(
                    onTap: () => context.push('/posts/${post.id}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        context.l10n.viewComments(post.commentCount),
                        style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Feed photos are square, so the feed keeps an even rhythm whatever was
/// uploaded and a post never takes over the screen.
const _mediaAspectRatio = 1.0;

/// Compact age of a post or comment: "now", "5m", "3h", "2d", then the date.
String timeAgo(AppLocalizations l10n, DateTime at) {
  final elapsed = DateTime.now().difference(at);
  if (elapsed.inMinutes < 1) return l10n.timeNow;
  if (elapsed.inHours < 1) return l10n.timeMinutes(elapsed.inMinutes);
  if (elapsed.inDays < 1) return l10n.timeHours(elapsed.inHours);
  if (elapsed.inDays < 7) return l10n.timeDays(elapsed.inDays);
  final local = at.toLocal();
  final format = local.year == DateTime.now().year ? DateFormat.MMMd(l10n.localeName) : DateFormat.yMMMd(l10n.localeName);
  return format.format(local);
}

/// Tap-to-play, not autoplay — a scrolling feed can have many of these
/// mounted at once, and autoplaying video for all of them would mean
/// several simultaneous network video streams before the user has asked
/// for any of them.
class _PostVideoPlayer extends StatefulWidget {
  const _PostVideoPlayer({required this.url});

  final String url;

  @override
  State<_PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<_PostVideoPlayer> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      })
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!_controller.value.isInitialized) {
      return AspectRatio(
        aspectRatio: _mediaAspectRatio,
        child: ColoredBox(
          color: scheme.onSurface.withValues(alpha: 0.06),
          child: const Center(child: BarberPoleLoader(size: 24)),
        ),
      );
    }
    final videoRatio = _controller.value.aspectRatio;
    return GestureDetector(
      onTap: _toggle,
      // Never taller than a photo post; a taller video is letterboxed.
      child: AspectRatio(
        aspectRatio: max(videoRatio, _mediaAspectRatio),
        child: ColoredBox(
          color: scheme.onSurface,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(aspectRatio: videoRatio, child: VideoPlayer(_controller)),
              if (!_controller.value.isPlaying)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: scheme.onSurface.withValues(alpha: 0.5), shape: BoxShape.circle),
                  child: Icon(Icons.play_arrow_rounded, size: 40, color: scheme.surface),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
