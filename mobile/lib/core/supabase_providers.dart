import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

/// The signed-in user's id right now, if any — a plain [Provider] rather
/// than reading `Supabase.instance` directly from widget build methods, so
/// screens that need this stay overridable (and therefore testable without
/// a real Supabase.initialize()) the same way every other Supabase-backed
/// provider in this app already is.
final currentAuthUserIdProvider = Provider<String?>((ref) {
  return ref.watch(supabaseClientProvider).auth.currentUser?.id;
});

/// Flips true when the password-reset deep link lands (Supabase fires
/// [AuthChangeEvent.passwordRecovery] on that temporary recovery session) so
/// the router can force the reset-password screen regardless of its other
/// rules. ResetPasswordScreen flips it back off once a new password is set.
class PasswordRecoveryNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(authStateChangesProvider, (_, next) {
      if (next.value?.event == AuthChangeEvent.passwordRecovery) state = true;
    });
    return false;
  }

  void clear() => state = false;
}

final passwordRecoveryProvider = NotifierProvider<PasswordRecoveryNotifier, bool>(
  PasswordRecoveryNotifier.new,
);
