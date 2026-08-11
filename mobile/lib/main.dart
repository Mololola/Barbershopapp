import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'core/router.dart';
import 'core/secure_local_storage.dart';

Future<void> main() async {
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
}

class BarbershopApp extends ConsumerWidget {
  const BarbershopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Barbershop',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
