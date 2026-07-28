import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../application/auth_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  File? _pickedImage;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _pickedImage = File(picked.path));
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
      appBar: AppBar(title: const Text('Edit profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundImage: _pickedImage != null
                    ? FileImage(_pickedImage!)
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
            const SizedBox(height: 32),
            if (profile != null)
              ListTile(
                title: const Text('Your referral code'),
                subtitle: Text(profile.referralCode),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: profile.referralCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Referral code copied')),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Manage worker profile'),
              subtitle: const Text('Set up legal name, bio, and availability to work at a shop'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/customer/worker-profile'),
            ),
          ],
        ),
      ),
    );
  }
}
