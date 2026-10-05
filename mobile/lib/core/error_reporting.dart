import 'dart:async';
import 'dart:developer' as developer;

import 'package:sentry_flutter/sentry_flutter.dart';

/// The one place an error/exception gets recorded for the developer's own
/// visibility, as opposed to what the user sees on screen (which is already
/// handled per-feature via AsyncValue error states): logged locally —
/// visible in `flutter run`'s console or DevTools — and sent to Sentry when
/// it's switched on (see main.dart).
void reportError(Object error, StackTrace stackTrace, {String? context}) {
  developer.log(
    context ?? 'Unhandled error',
    name: 'barbershop.error',
    error: error,
    stackTrace: stackTrace,
    level: 1000, // SEVERE
  );
  if (Sentry.isEnabled) {
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) => scope.setTag('context', context ?? 'unhandled'),
      ),
    );
  }
}
