import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'core/error_reporting.dart';
import 'core/router.dart';
import 'core/secure_local_storage.dart';
import 'core/theme.dart';

Future<void> main() async {
  // Catches anything not already caught by a feature's own AsyncValue.guard
  // — a raw exception outside a guarded context, a Flutter framework error
  // during a widget build, or an async error on a zone that isn't awaited
  // anywhere. Without this, any of those crash silently to a blank/frozen
  // screen with no trace of what happened.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    reportError(details.exception, details.stack ?? StackTrace.current, context: 'FlutterError');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    reportError(error, stack, context: 'PlatformDispatcher');
    return true;
  };

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        // Matches supabase_flutter's own default key formula (see
        // SharedPreferencesLocalStorage's construction in its source) so the
        // migration in SecureLocalStorage.initialize() finds the same
        // pre-existing session a prior app version would have written.
        localStorage: SecureLocalStorage(
          persistSessionKey: 'sb-${Uri.parse(Env.supabaseUrl).host.split('.').first}-auth-token',
        ),
      ),
    );
    runApp(const ProviderScope(child: BarbershopApp()));
  }, (error, stack) => reportError(error, stack, context: 'runZonedGuarded'));
}

class BarbershopApp extends ConsumerWidget {
  const BarbershopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Barbershop',
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
