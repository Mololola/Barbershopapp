import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/picked_media.dart';
import '../application/auth_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  XFile? _pickedImage;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _pickedImage = picked);
  }

  Future<void> _save() async {
    final image = _pickedImage;
    if (image == null) return;
    final success = await ref.read(profileEditControllerProvider.notifier).updateAvatar(image);
    if (!mounted) return;
    if (success) setState(() => _pickedImage = null);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    final editState = ref.watch(profileEditControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile photo')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundImage: _pickedImage != null
                    ? pickedImage(_pickedImage!)
                    : (profile?.avatarUrl != null ? NetworkImage(profile!.avatarUrl!) : null) as ImageProvider?,
                child: (_pickedImage == null && profile?.avatarUrl == null)
                    ? const Icon(Icons.person, size: 48)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Change photo'),
              ),
            ),
            const SizedBox(height: 16),
            if (editState.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  editState.error.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: (_pickedImage != null && !editState.isLoading) ? _save : null,
              child: editState.isLoading
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
