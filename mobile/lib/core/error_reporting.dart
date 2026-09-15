import 'dart:developer' as developer;

/// The one place an error/exception gets recorded for the developer's own
/// visibility, as opposed to what the user sees on screen (which is already
/// handled per-feature via AsyncValue error states). Right now this only
/// logs locally — visible in `flutter run`'s console or DevTools — because
/// real remote crash reporting (Sentry, Crashlytics) needs its own account
/// and DSN/config that don't exist yet. Once that's set up, this is the
/// single function to change; nothing else in the app needs to know.
void reportError(Object error, StackTrace stackTrace, {String? context}) {
  developer.log(
    context ?? 'Unhandled error',
    name: 'barbershop.error',
    error: error,
    stackTrace: stackTrace,
    level: 1000, // SEVERE
  );
}
