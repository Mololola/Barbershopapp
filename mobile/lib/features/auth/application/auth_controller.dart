import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api_client.dart';
import '../../../core/env.dart';
import '../../../core/supabase_providers.dart';
import '../data/account_api_client.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

final accountApiClientProvider = Provider<AccountApiClient>((ref) {
  return AccountApiClient(ref.watch(apiClientProvider));
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
  final dobValue = metadata?['date_of_birth'] as String?;
  if (roleValue == null || username == null) return null;

  await repository.insertProfile(
    id: user.id,
    role: AccountRoleX.fromWireValue(roleValue),
    username: username,
    dateOfBirth: dobValue != null ? DateTime.parse(dobValue) : null,
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
    required DateTime dateOfBirth,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(supabaseClientProvider).auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: Env.authCallbackUrl,
        data: {
          'role': role.wireValue,
          'username': username,
          'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
        },
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

  /// The OAuth-first-login path: an already-authenticated user (just
  /// completed Google/Apple sign-in) with no `profiles` row yet, so there's
  /// no signUp() call to make — just the row, same as email/password's lazy
  /// insert in [currentProfileProvider] but triggered explicitly since there
  /// was no signUp() to have carried role/username as user metadata.
  Future<void> completeOAuthProfile({
    required AccountRole role,
    required String username,
    required DateTime dateOfBirth,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = ref.read(supabaseClientProvider).auth.currentUser!.id;
      await ref.read(profileRepositoryProvider).insertProfile(
            id: userId,
            role: role,
            username: username,
            dateOfBirth: dateOfBirth,
          );
      ref.invalidate(currentProfileProvider);
      await ref.read(currentProfileProvider.future);
    });
  }

  Future<void> signInWithOAuth(OAuthProvider provider) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(supabaseClientProvider)
          .auth
          .signInWithOAuth(provider, redirectTo: Env.authCallbackUrl);
    });
  }

  Future<void> requestPasswordReset(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(supabaseClientProvider).auth.resetPasswordForEmail(email, redirectTo: Env.authCallbackUrl);
    });
  }

  /// Called from ResetPasswordScreen against the temporary recovery session
  /// the emailed link signs the user into — see [passwordRecoveryProvider].
  Future<void> updatePassword(String newPassword) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(supabaseClientProvider).auth.updateUser(UserAttributes(password: newPassword));
      ref.read(passwordRecoveryProvider.notifier).clear();
    });
  }

  Future<void> resendConfirmationEmail(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(supabaseClientProvider).auth.resend(type: OtpType.signup, email: email);
    });
  }

  /// Throws [ApiException] (409) if the backend blocks deletion — the caller
  /// surfaces that message rather than treating it as a generic failure.
  Future<void> deleteAccount() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(accountApiClientProvider).deleteAccount();
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
