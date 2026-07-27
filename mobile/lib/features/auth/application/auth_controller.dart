import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_providers.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

final profileByIdProvider = FutureProvider.family<Profile?, String>((ref, profileId) {
  return ref.watch(profileRepositoryProvider).fetchProfile(profileId);
});

/// Fetches the signed-in user's profile, lazily creating it from the
/// role/display-name captured as auth user metadata at sign-up. Doing the
/// insert here (rather than immediately after signUp()) means it works
/// whether or not the Supabase project requires email confirmation: signUp()
/// may not return an active session, but this provider re-runs once one
/// exists and the user is genuinely authenticated, which is what the RLS
/// insert policy (auth.uid() = id) requires anyway.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final authState = ref.watch(authStateChangesProvider).value;
  final client = ref.watch(supabaseClientProvider);
  final user = authState?.session?.user ?? client.auth.currentUser;
  if (user == null) return null;

  final repository = ref.watch(profileRepositoryProvider);
  final existing = await repository.fetchOwnProfile(user.id);
  if (existing != null) return existing;

  final metadata = user.userMetadata;
  final roleValue = metadata?['role'] as String?;
  final username = metadata?['username'] as String?;
  if (roleValue == null || username == null) return null;

  await repository.insertProfile(
    id: user.id,
    role: AccountRoleX.fromWireValue(roleValue),
    username: username,
  );
  return repository.fetchOwnProfile(user.id);
});

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(AuthController.new);

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signUp({
    required String email,
    required String password,
    required AccountRole role,
    required String username,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(supabaseClientProvider).auth.signUp(
        email: email,
        password: password,
        data: {'role': role.wireValue, 'username': username},
      );
      ref.invalidate(currentProfileProvider);
      // Wait for the lazy profile insert (see currentProfileProvider) to run so
      // a taken username surfaces as an error here, not silently on the router.
      await ref.read(currentProfileProvider.future);
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(supabaseClientProvider).auth.signInWithPassword(email: email, password: password);
      ref.invalidate(currentProfileProvider);
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(supabaseClientProvider).auth.signOut();
      ref.invalidate(currentProfileProvider);
    });
  }
}

final profileEditControllerProvider =
    AsyncNotifierProvider<ProfileEditController, void>(ProfileEditController.new);

class ProfileEditController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> updateAvatar(File image) async {
    state = const AsyncLoading();
    var success = false;
    state = await AsyncValue.guard(() async {
      final profile = await ref.read(currentProfileProvider.future);
      if (profile == null) throw StateError('No signed-in profile.');
      await ref.read(profileRepositoryProvider).updateAvatar(profileId: profile.id, image: image);
      ref.invalidate(currentProfileProvider);
      ref.invalidate(profileByIdProvider(profile.id));
      await ref.read(currentProfileProvider.future);
      success = true;
    });
    return success;
  }
}
