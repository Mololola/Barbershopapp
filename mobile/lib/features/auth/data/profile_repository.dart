import 'package:supabase_flutter/supabase_flutter.dart';

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
  }) async {
    try {
      await _client.from('profiles').insert({
        'id': id,
        'role': role.wireValue,
        'username': username,
      });
    } on PostgrestException catch (e) {
      if (e.code == _uniqueViolation) {
        throw UsernameTakenException(username);
      }
      rethrow;
    }
  }

  Future<Profile?> fetchOwnProfile(String userId) async {
    final row = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (row == null) return null;
    return Profile.fromRow(row);
  }
}
