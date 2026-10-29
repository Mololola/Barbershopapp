import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';
import 'supabase_providers.dart';

/// Everything saved for offline use lives under this prefix, so signing out
/// can wipe it in one go.
const _prefix = 'offline:';

/// A request that failed because there's no connection, as opposed to the
/// server refusing it.
bool isOfflineError(Object error) =>
    error is http.ClientException || error is TimeoutException || error is AuthRetryableFetchException;

class ConnectionStatus {
  const ConnectionStatus({required this.online, required this.reconnects});

  final bool online;

  /// Goes up each time the connection comes back.
  final int reconnects;
}

/// Online until a request fails for lack of connection; then checks every
/// few seconds until it's back.
class ConnectionNotifier extends Notifier<ConnectionStatus> {
  static const _checkEvery = Duration(seconds: 15);

  Timer? _check;

  @override
  ConnectionStatus build() {
    ref.onDispose(() => _check?.cancel());
    return const ConnectionStatus(online: true, reconnects: 0);
  }

  void reportOffline() {
    if (!state.online) return;
    state = ConnectionStatus(online: false, reconnects: state.reconnects);
    _check = Timer.periodic(_checkEvery, (_) => _checkConnection());
  }

  void reportOnline() {
    if (state.online) return;
    _check?.cancel();
    state = ConnectionStatus(online: true, reconnects: state.reconnects + 1);
  }

  Future<void> _checkConnection() async {
    try {
      // Any answer at all, even an error status, means we're reachable.
      await http.head(Uri.parse(Env.supabaseUrl)).timeout(const Duration(seconds: 5));
      reportOnline();
    } catch (_) {
      // Still offline; the timer tries again.
    }
  }
}

final connectionProvider = NotifierProvider<ConnectionNotifier, ConnectionStatus>(ConnectionNotifier.new);

final reconnectsProvider = Provider<int>((ref) => ref.watch(connectionProvider.select((c) => c.reconnects)));

/// Keeps the last good copy of what a screen loaded, per signed-in user, and
/// serves it when there's no connection.
class OfflineCache {
  OfflineCache(this._ref);

  final Ref _ref;

  Future<List<Map<String, dynamic>>> rows(String key, Future<List<Map<String, dynamic>>> Function() fetch) async {
    final result = await _read(key, fetch);
    return [for (final row in result as List) row as Map<String, dynamic>];
  }

  Future<Map<String, dynamic>?> row(String key, Future<Map<String, dynamic>?> Function() fetch) async {
    return await _read(key, fetch) as Map<String, dynamic>?;
  }

  /// A request taking longer than this is treated as having no connection,
  /// so a weak signal doesn't leave a screen loading indefinitely.
  static const timeout = Duration(seconds: 6);

  Future<Object?> _read(String key, Future<Object?> Function() fetch) async {
    final storeKey = _storeKey(key);
    // Already known to be offline: show the saved copy straight away. The
    // connection check brings the screen back to fresh data when it returns.
    if (!_ref.read(connectionProvider).online && storeKey != null) {
      final saved = (await SharedPreferences.getInstance()).getString(storeKey);
      if (saved != null) return jsonDecode(saved);
    }
    try {
      final fresh = await fetch().timeout(timeout);
      _ref.read(connectionProvider.notifier).reportOnline();
      if (storeKey != null) await (await SharedPreferences.getInstance()).setString(storeKey, jsonEncode(fresh));
      return fresh;
    } catch (error) {
      if (!isOfflineError(error)) rethrow;
      _ref.read(connectionProvider.notifier).reportOffline();
      final saved = storeKey == null ? null : (await SharedPreferences.getInstance()).getString(storeKey);
      if (saved == null) rethrow;
      return jsonDecode(saved);
    }
  }

  /// Saved data belongs to whoever is signed in, so one account never sees
  /// another's on a shared phone.
  String? _storeKey(String key) {
    final userId = _ref.read(currentAuthUserIdProvider);
    return userId == null ? null : '$_prefix$userId:$key';
  }

  /// A list kept on the phone for this user, e.g. messages waiting to send.
  Future<List<Map<String, dynamic>>> readList(String key) async {
    final storeKey = _storeKey(key);
    final saved = storeKey == null ? null : (await SharedPreferences.getInstance()).getString(storeKey);
    if (saved == null) return [];
    return [for (final item in jsonDecode(saved) as List) item as Map<String, dynamic>];
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> items) async {
    final storeKey = _storeKey(key);
    if (storeKey == null) return;
    await (await SharedPreferences.getInstance()).setString(storeKey, jsonEncode(items));
  }

  /// Wipes everything saved for offline use, for every account.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((key) => key.startsWith(_prefix)).toList()) {
      await prefs.remove(key);
    }
  }
}

/// Rebuilt each time the connection comes back, and with it every repository
/// and the screens reading through them, which then load fresh data.
final offlineCacheProvider = Provider<OfflineCache>((ref) {
  ref.watch(reconnectsProvider);
  return OfflineCache(ref);
});
