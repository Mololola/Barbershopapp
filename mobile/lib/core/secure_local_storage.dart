import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists the Supabase session in the OS Keychain (iOS) / Keystore-backed
/// encrypted storage (Android) instead of supabase_flutter's default
/// [SharedPreferencesLocalStorage], which stores the access/refresh tokens
/// as plaintext.
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage({required this.persistSessionKey});

  /// Must match whatever key Supabase.initialize would have used by
  /// default — see supabase_flutter's own default:
  /// `"sb-${Uri.parse(url).host.split(".").first}-auth-token"`. Passed in
  /// rather than hardcoded here so this stays correct if the project's
  /// Supabase URL ever changes.
  final String persistSessionKey;

  // Default options are Keychain (iOS) / Keystore-backed encryption
  // (Android) out of the box — encryptedSharedPreferences is deprecated as
  // of this package version (Google deprecated the underlying Jetpack
  // Security library; data is now auto-migrated to its replacement
  // cipher on first access without needing that flag).
  static const _secureStorage = FlutterSecureStorage();

  @override
  Future<void> initialize() async {
    // One-time migration: a session already sitting in plaintext
    // SharedPreferences (written by a pre-this-change app version) is
    // copied into secure storage and the plaintext copy is deleted —
    // preserving the user's logged-in state across the update rather than
    // forcing a re-login, and just as importantly, actually removing the
    // vulnerable plaintext copy instead of leaving it on disk next to the
    // new secure one. Safe to run on every launch: a no-op once the
    // plaintext key is gone.
    final legacyPrefs = await SharedPreferences.getInstance();
    final legacySession = legacyPrefs.getString(persistSessionKey);
    if (legacySession != null) {
      await _secureStorage.write(key: persistSessionKey, value: legacySession);
      await legacyPrefs.remove(persistSessionKey);
    }
  }

  @override
  Future<bool> hasAccessToken() {
    return _secureStorage.containsKey(key: persistSessionKey);
  }

  @override
  Future<String?> accessToken() {
    return _secureStorage.read(key: persistSessionKey);
  }

  @override
  Future<void> removePersistedSession() {
    return _secureStorage.delete(key: persistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) {
    return _secureStorage.write(key: persistSessionKey, value: persistSessionString);
  }
}
