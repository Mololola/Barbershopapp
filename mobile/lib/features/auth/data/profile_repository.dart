import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/picked_media.dart';
import '../domain/profile.dart';

class UsernameTakenException implements Exception {
  const UsernameTakenException(this.username);

  final String username;

  @override
  String toString() => 'Username "$username" is already taken.';
}

class ProfileRepository {
  ProfileRepository(this._client);

  static const _uniqueViolation = '23505';

  final SupabaseClient _client;

  Future<void> insertProfile({
    required String id,
    required AccountRole role,
    required String username,
    DateTime? dateOfBirth,
  }) async {
    try {
      await _client.from('profiles').insert({
        'id': id,
        'role': role.wireValue,
        'username': username,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
        // Only ever called after the sign-up form's required Terms/Privacy
        // checkbox validates, so this timestamp is a real acceptance
        // record, not decoration.
        'terms_accepted_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on PostgrestException catch (e) {
      if (e.code == _uniqueViolation) {
        throw UsernameTakenException(username);
      }
      rethrow;
    }
  }

  Future<Profile?> fetchOwnProfile(String userId) async {
    final row = await _client.from('profiles').select('*, is_minor:profile_is_minor').eq('id', userId).maybeSingle();
    if (row == null) return null;
    return Profile.fromRow(row);
  }

  /// Same query as [fetchOwnProfile] — `profiles` RLS already permits any
  /// signed-in user to read any profile — named separately so call sites
  /// (e.g. viewing another user's profile) read clearly.
  Future<Profile?> fetchProfile(String profileId) => fetchOwnProfile(profileId);

  Future<List<Profile>> searchByUsername(String query) async {
    final rows = await _client.from('profiles').select('*, is_minor:profile_is_minor').ilike('username', '%$query%').limit(20);
    return rows.map(Profile.fromRow).toList();
  }

  Future<void> updateAvatar({required String profileId, required XFile image}) async {
    final avatarUrl = await uploadAvatarImage(profileId, image);
    await updateAvatarUrl(profileId, avatarUrl);
  }

  /// Uploaded to the same path every time (`upsert: true`) so edits overwrite
  /// the previous photo instead of accumulating orphaned files. `uid` is
  /// whoever owns the `avatars/<uid>/...` folder under storage RLS — not
  /// necessarily the profile the resulting URL gets written to (a business
  /// logo upload uses the owner's own uid but also updates `businesses`).
  /// [fileName] keeps a shop's cover photo from overwriting its logo.
  Future<String> uploadAvatarImage(String uid, XFile image, {String fileName = 'avatar'}) async {
    final path = '$uid/$fileName${extensionOf(image)}';
    await _client.storage.from('avatars').uploadBinary(
          path,
          await image.readAsBytes(),
          fileOptions: const FileOptions(upsert: true),
        );
    // Cache-bust: the path (and therefore URL) is identical across edits
    // since it's upserted, so without this a client that already fetched
    // the old image would keep showing it.
    return '${_client.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> updateAvatarUrl(String profileId, String avatarUrl) async {
    await _client.from('profiles').update({'avatar_url': avatarUrl}).eq('id', profileId);
  }
}
