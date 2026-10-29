import '../../../core/l10n.dart';
import '../../../core/loading.dart';
import '../../../core/picked_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../auth/application/auth_controller.dart';
import '../application/feed_controller.dart';

const _maxVideoDuration = Duration(minutes: 1);

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _bodyController = TextEditingController();
  XFile? _image;
  XFile? _video;
  String? _mediaError;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _bodyController.text.trim().isNotEmpty || _image != null || _video != null;

  Future<void> _pickImage() async {
    // Compressed client-side rather than uploading the original — a modern
    // phone photo can be several MB at full resolution, and a feed image
    // doesn't need to be larger than this. The post-media bucket's
    // file_size_limit is the actual backstop; this is what keeps normal
    // uploads well under it instead of relying on that cap alone.
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1920, imageQuality: 80);
    if (picked == null) return;
    setState(() {
      _image = picked;
      _video = null;
      _mediaError = null;
    });
  }

  Future<void> _pickVideo() async {
    // maxDuration only reliably trims a freshly *recorded* video — the
    // gallery can still hand back something longer, so the actual limit is
    // enforced below by inspecting the picked file itself, not by trusting
    // this alone.
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: _maxVideoDuration);
    if (picked == null) return;

    final controller = pickedVideoController(picked);
    Duration duration;
    try {
      await controller.initialize();
      duration = controller.value.duration;
    } finally {
      await controller.dispose();
    }

    if (duration > _maxVideoDuration) {
      setState(() => _mediaError = context.l10n.videoTooLong(duration.inSeconds));
      return;
    }

    setState(() {
      _video = picked;
      _image = null;
      _mediaError = null;
    });
  }

  Future<void> _submit() async {
    final success = await ref.read(feedActionControllerProvider.notifier).createPost(
          body: _bodyController.text.trim().isEmpty ? null : _bodyController.text.trim(),
          image: _image,
          video: _video,
        );
    if (!mounted) return;
    if (success) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(feedActionControllerProvider);

    // Minor accounts don't post — kept private-by-default, see the
    // guardian-consent design. The real enforcement is RLS; this just
    // avoids a dead-end composer that would fail on submit.
    if (ref.watch(currentProfileProvider).value?.isMinor == true) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.newPost)),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(context.l10n.postingUnavailable))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.newPost)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            TextField(
              controller: _bodyController,
              decoration: InputDecoration(labelText: context.l10n.whatsGoingOn),
              maxLines: 4,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            if (_image != null) Image(image: pickedImage(_image!), height: 200),
            if (_video != null) _LocalVideoPreview(file: _video!, height: 200),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(_image == null ? context.l10n.addAPhoto : context.l10n.changePhoto),
                ),
                TextButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.videocam_outlined),
                  label: Text(_video == null ? context.l10n.addAVideo : context.l10n.changeVideo),
                ),
              ],
            ),
            if (_mediaError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_mediaError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 16),
            if (actionState.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  describeError(context.l10n, actionState.error),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: (_canSubmit && !actionState.isLoading) ? _submit : null,
              child: actionState.isLoading
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(context.l10n.post),
            ),
          ],
        ),
      ),
    );
  }
}

/// A muted, looping preview of the locally-picked video file before upload.
class _LocalVideoPreview extends StatefulWidget {
  const _LocalVideoPreview({required this.file, required this.height});

  final XFile file;
  final double height;

  @override
  State<_LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends State<_LocalVideoPreview> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = pickedVideoController(widget.file)
      ..setVolume(0)
      ..setLooping(true)
      ..initialize().then((_) {
        if (mounted) setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return SizedBox(height: widget.height, child: const LoadingView());
    }
    return SizedBox(
      height: widget.height,
      child: AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller)),
    );
  }
}
