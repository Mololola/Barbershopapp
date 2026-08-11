import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../application/feed_controller.dart';

const _maxVideoDuration = Duration(minutes: 1);

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _bodyController = TextEditingController();
  File? _image;
  File? _video;
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
      _image = File(picked.path);
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

    final file = File(picked.path);
    final controller = VideoPlayerController.file(file);
    Duration duration;
    try {
      await controller.initialize();
      duration = controller.value.duration;
    } finally {
      await controller.dispose();
    }

    if (duration > _maxVideoDuration) {
      setState(() => _mediaError = 'Videos must be 1 minute or shorter (this one is ${duration.inSeconds}s).');
      return;
    }

    setState(() {
      _video = file;
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

    return Scaffold(
      appBar: AppBar(title: const Text('New post')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(labelText: "What's going on?"),
              maxLines: 4,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            if (_image != null) Image.file(_image!, height: 200),
            if (_video != null) _LocalVideoPreview(file: _video!, height: 200),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(_image == null ? 'Add a photo' : 'Change photo'),
                ),
                TextButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.videocam_outlined),
                  label: Text(_video == null ? 'Add a video' : 'Change video'),
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
                  actionState.error.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: (_canSubmit && !actionState.isLoading) ? _submit : null,
              child: actionState.isLoading
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Post'),
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

  final File file;
  final double height;

  @override
  State<_LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends State<_LocalVideoPreview> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
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
      return SizedBox(height: widget.height, child: const Center(child: CircularProgressIndicator()));
    }
    return SizedBox(
      height: widget.height,
      child: AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller)),
    );
  }
}
