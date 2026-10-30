import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/adaptive_chrome.dart';
import 'core/app_language.dart';
import 'core/env.dart';
import 'core/error_reporting.dart';
import 'core/l10n.dart';
import 'core/launch_animation.dart';
import 'core/offline_banner.dart';
import 'core/router.dart';
import 'core/secure_local_storage.dart';
import 'core/system_bars.dart';
import 'core/theme.dart';
import 'features/customer/application/review_controller.dart';
import 'features/messaging/application/messaging_controller.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Real paths on the website (/business/finance, not /#/business/finance):
    // shareable, and the URL's fragment stays free for Supabase's sign-in
    // links. No effect in the app.
    usePathUrlStrategy();
    // Off without a DSN (local dev). Native crashes are caught by Sentry
    // itself; Dart errors go through reportError below.
    if (Env.sentryDsn.isNotEmpty) {
      await SentryFlutter.init((options) => options.dsn = Env.sentryDsn);
    }

    // Catches anything not already caught by a feature's own AsyncValue.guard
    // — a raw exception outside a guarded context, a Flutter framework error
    // during a widget build, or an async error on a zone that isn't awaited
    // anywhere. Without this, any of those crash silently to a blank/frozen
    // screen with no trace of what happened. Set after Sentry's init, which
    // installs its own versions of these two: replacing them keeps each
    // error reported once, via reportError.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      reportError(details.exception, details.stack ?? StackTrace.current, context: 'FlutterError');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      reportError(error, stack, context: 'PlatformDispatcher');
      return true;
    };

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
    // Kept alive so anything written offline goes out as soon as it can.
    ref.listen(messageOutboxProvider, (_, _) {});
    ref.listen(reviewOutboxProvider, (_, _) {});
    return MaterialApp.router(
      title: 'Fadra Cut',
      theme: AppTheme.light,
      locale: ref.watch(appLanguageProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          LaunchAnimation(child: SystemBarsSafeArea(child: OfflineBanner(child: AdaptiveChrome(child: child!)))),
    );
  }
}
