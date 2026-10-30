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

/// Counts changes found by background refreshes, a short moment after the
/// last one so a burst of them on opening the app reloads screens once.
class SavedDataChangedNotifier extends Notifier<int> {
  Timer? _settle;

  @override
  int build() {
    ref.onDispose(() => _settle?.cancel());
    return 0;
  }

  void changed() {
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 300), () => state++);
  }
}

final savedDataChangedProvider = NotifierProvider<SavedDataChangedNotifier, int>(SavedDataChangedNotifier.new);

/// Saved copies already shown since the app started. Each is shown first
/// only once; later loads (pull to refresh, after an action) go to the
/// server, so they never show out-of-date data.
final _shownFirst = <String>{};

/// Keeps the last good copy of what a screen loaded, per signed-in user. The
/// first time a screen opens it shows that copy at once and refreshes it in
/// the background; with no connection it keeps showing it.
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
    // Read now: the cache can be rebuilt while a request is in flight.
    final connection = _ref.read(connectionProvider.notifier);
    final online = _ref.read(connectionProvider).online;
    final saved = storeKey == null ? null : (await SharedPreferences.getInstance()).getString(storeKey);
    if (saved != null && !online) return jsonDecode(saved);
    if (saved != null && _shownFirst.add(storeKey!)) {
      unawaited(_refreshInBackground(storeKey, fetch, saved, connection));
      return jsonDecode(saved);
    }
    try {
      final fresh = await fetch().timeout(timeout);
      connection.reportOnline();
      if (storeKey != null) await (await SharedPreferences.getInstance()).setString(storeKey, jsonEncode(fresh));
      return fresh;
    } catch (error) {
      if (!isOfflineError(error)) rethrow;
      connection.reportOffline();
      if (saved == null) rethrow;
      return jsonDecode(saved);
    }
  }

  /// Fetches what was just shown from the saved copy; if it changed, saves it
  /// and has the screens reload.
  Future<void> _refreshInBackground(
    String storeKey,
    Future<Object?> Function() fetch,
    String saved,
    ConnectionNotifier connection,
  ) async {
    final changed = _ref.read(savedDataChangedProvider.notifier);
    try {
      final fresh = jsonEncode(await fetch().timeout(timeout));
      connection.reportOnline();
      if (fresh == saved) return;
      await (await SharedPreferences.getInstance()).setString(storeKey, fresh);
      changed.changed();
    } catch (error) {
      if (isOfflineError(error)) connection.reportOffline();
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
    _shownFirst.clear();
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((key) => key.startsWith(_prefix)).toList()) {
      await prefs.remove(key);
    }
  }
}

/// Rebuilt when the connection comes back or a background refresh found
/// changes, and with it every repository and the screens reading through
/// them, which then load fresh data.
final offlineCacheProvider = Provider<OfflineCache>((ref) {
  ref.watch(reconnectsProvider);
  ref.watch(savedDataChangedProvider);
  return OfflineCache(ref);
});
