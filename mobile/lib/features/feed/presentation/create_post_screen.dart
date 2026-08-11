import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../application/feed_controller.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _bodyController = TextEditingController();
  File? _image;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _bodyController.text.trim().isNotEmpty || _image != null;

  Future<void> _pickImage() async {
    // Compressed client-side rather than uploading the original — a modern
    // phone photo can be several MB at full resolution, and a feed image
    // doesn't need to be larger than this. The post-media bucket's
    // file_size_limit (see the c8a1f5d47b6e migration) is the actual
    // backstop; this is what keeps normal uploads well under it instead of
    // relying on that cap alone.
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1920, imageQuality: 80);
    if (picked == null) return;
    setState(() => _image = File(picked.path));
  }

  Future<void> _submit() async {
    final success = await ref.read(feedActionControllerProvider.notifier).createPost(
          body: _bodyController.text.trim().isEmpty ? null : _bodyController.text.trim(),
          image: _image,
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
            TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: Text(_image == null ? 'Add a photo' : 'Change photo'),
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
