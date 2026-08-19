import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/app_network_image.dart';
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

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) _post = widget.post;
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update like.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(feedActionControllerProvider);
    final post = _post;

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
            trailing: widget.isMine
                ? IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: actionState.isLoading
                        ? null
                        : () => ref.read(feedActionControllerProvider.notifier).deletePost(post.id),
                  )
                : null,
          ),
          if (post.mediaUrl != null && post.mediaType == PostMediaType.video)
            _PostVideoPlayer(url: post.mediaUrl!, height: 320)
          else if (post.mediaUrl != null)
            SizedBox(
              width: double.infinity,
              height: 320,
              child: AppNetworkImage(post.mediaUrl!, fit: BoxFit.contain),
            ),
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
                onPressed: _toggleLike,
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

/// Tap-to-play, not autoplay — a scrolling feed can have many of these
/// mounted at once, and autoplaying video for all of them would mean
/// several simultaneous network video streams before the user has asked
/// for any of them.
class _PostVideoPlayer extends StatefulWidget {
  const _PostVideoPlayer({required this.url, required this.height});

  final String url;
  final double height;

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
    if (!_controller.value.isInitialized) {
      return SizedBox(height: widget.height, child: const Center(child: CircularProgressIndicator()));
    }
    return GestureDetector(
      onTap: _toggle,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller)),
            if (!_controller.value.isPlaying)
              const Icon(Icons.play_circle_fill, size: 64, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
