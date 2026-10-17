import 'package:flutter/foundation.dart';

// Supplied at build/run time via --dart-define-from-file, e.g.:
//   flutter run --dart-define-from-file=env.json
// env.json is untracked (see .gitignore) — copy env.json.example and fill in
// your Supabase project's URL and anon key.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Empty turns crash reporting off — see main.dart.
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  static const fastApiBaseUrl = String.fromEnvironment(
    'FASTAPI_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// Where Supabase redirects once an OAuth sign-in completes — the app is
  /// already open and active at that point, so the OS can hand the custom
  /// scheme straight back to it. Must match the scheme/host registered in
  /// AndroidManifest.xml's intent-filter and iOS Info.plist's
  /// CFBundleURLTypes, and the redirect URL allow-listed in the Supabase
  /// dashboard (Authentication > URL Configuration). On the website it's the
  /// site itself, which picks the sign-in up from the URL.
  static String get authCallbackUrl => kIsWeb ? _webSignIn : 'barbershopapp://auth-callback';

  /// Where Supabase redirects after a *emailed* signup-confirmation or
  /// password-reset link — unlike [authCallbackUrl], this is opened from a
  /// mail client (often on a completely different, possibly desktop,
  /// device), so it must be a real https:// page rather than the bare
  /// custom scheme, which just shows a blank tab with no app to catch it.
  /// That page then forwards into [authCallbackUrl] itself. Always the
  /// production backend, regardless of which FASTAPI_BASE_URL this build
  /// uses — an emailed link is clicked from anywhere, not just wherever the
  /// developer's own machine can reach. Requested from the website, the link
  /// goes back to the website: the sign-in it carries can only be completed
  /// in the browser that asked for it.
  static String get emailConfirmationRedirectUrl =>
      kIsWeb ? _webSignIn : 'https://barbershopapp-qrpk.onrender.com/auth/confirmed';

  /// Same idea as [emailConfirmationRedirectUrl], for the password-reset
  /// email — a separate page because what the person has to do next differs.
  static String get passwordResetRedirectUrl =>
      kIsWeb ? _webSignIn : 'https://barbershopapp-qrpk.onrender.com/auth/reset';

  static String get _webSignIn => '${Uri.base.origin}/sign-in';
}
