import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n.dart';
import '../application/auth_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _say(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  /// The photo saves as soon as it's picked; there's nothing else to confirm.
  Future<void> _pickImage(ImageSource source) async {
    // Shown at most ~96 px across; 512 keeps it sharp on any screen
    // without uploading a multi-megabyte camera photo.
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (picked == null) return;
    final success = await ref.read(profileEditControllerProvider.notifier).updateAvatar(picked);
    if (mounted && success) _say(context.l10n.photoUpdated);
  }

  Future<void> _removeImage() async {
    final success = await ref.read(profileEditControllerProvider.notifier).removeAvatar();
    if (mounted && success) _say(context.l10n.photoRemoved);
  }

  Future<void> _saveDetails() async {
    FocusScope.of(context).unfocus();
    final success = await ref
        .read(profileEditControllerProvider.notifier)
        .saveDetails(displayName: _displayNameController.text, bio: _bioController.text);
    if (mounted && success) _say(context.l10n.profileSaved);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    final editState = ref.watch(profileEditControllerProvider);
    final busy = editState.isLoading;
    final l10n = context.l10n;

    if (profile != null && !_initialized) {
      _initialized = true;
      _displayNameController.text = profile.displayName ?? '';
      _bioController.text = profile.bio ?? '';
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editProfile)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundImage:
                          profile?.avatarUrl != null ? CachedNetworkImageProvider(profile!.avatarUrl!) : null,
                      child: profile?.avatarUrl == null ? const Icon(Icons.person, size: 48) : null,
                    ),
                    if (busy) const CircularProgressIndicator(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  // The browser's file picker already offers the camera where there is one.
                  if (!kIsWeb)
                    TextButton.icon(
                      onPressed: busy ? null : () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(l10n.takePhoto),
                    ),
                  TextButton.icon(
                    onPressed: busy ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.image_outlined),
                    label: Text(l10n.choosePhoto),
                  ),
                  if (profile?.avatarUrl != null)
                    TextButton.icon(
                      onPressed: busy ? null : _removeImage,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l10n.removePhoto),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _displayNameController,
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(
                  labelText: l10n.displayNameOptional,
                  helperText: profile == null ? null : l10n.shownAboveUsername(profile.username),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bioController,
                maxLength: 160,
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l10n.bioOptional, alignLabelWithHint: true),
              ),
              const SizedBox(height: 16),
              if (editState.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    describeError(l10n, editState.error),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              FilledButton(
                onPressed: busy || profile == null ? null : _saveDetails,
                child: Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
