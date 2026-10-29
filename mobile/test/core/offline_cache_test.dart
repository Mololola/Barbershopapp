import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/offline_cache.dart';
import 'package:mobile/core/supabase_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  ProviderContainer containerFor(String? userId) {
    final container = ProviderContainer(overrides: [currentAuthUserIdProvider.overrideWithValue(userId)]);
    addTearDown(container.dispose);
    return container;
  }

  Future<List<Map<String, dynamic>>> offline() => Future.error(http.ClientException('no connection'));

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('serves the last saved copy when offline, and reports being offline', () async {
    final container = containerFor('u1');
    final cache = container.read(offlineCacheProvider);

    final fresh = await cache.rows('bookings', () async => [
          {'id': 'b1'},
        ]);
    expect(fresh.single['id'], 'b1');
    expect(container.read(connectionProvider).online, isTrue);

    final saved = await cache.rows('bookings', offline);
    expect(saved.single['id'], 'b1');
    expect(container.read(connectionProvider).online, isFalse);
  });

  test("with nothing saved, or another account's data, the error comes through", () async {
    await containerFor('u1').read(offlineCacheProvider).rows('bookings', () async => [
          {'id': 'b1'},
        ]);

    final other = containerFor('u2').read(offlineCacheProvider);
    await expectLater(other.rows('bookings', offline), throwsA(isA<http.ClientException>()));
  });

  test('a request with no answer gives up after the time limit; once offline, the saved copy is instant', () {
    fakeAsync((async) {
      final container = containerFor('u1');
      List<Map<String, dynamic>>? shown;
      container.read(offlineCacheProvider).rows('bookings', () async => [
            {'id': 'b1'},
          ]);
      async.flushMicrotasks();

      container.read(offlineCacheProvider).rows('bookings', () => Completer<List<Map<String, dynamic>>>().future).then(
            (rows) => shown = rows,
          );
      async.elapse(OfflineCache.timeout - const Duration(seconds: 1));
      expect(shown, isNull);
      async.elapse(const Duration(seconds: 1));
      expect(shown!.single['id'], 'b1');
      expect(container.read(connectionProvider).online, isFalse);

      var fetched = false;
      shown = null;
      container.read(offlineCacheProvider).rows('bookings', () async {
        fetched = true;
        return [];
      }).then((rows) => shown = rows);
      async.flushMicrotasks();
      expect(fetched, isFalse);
      expect(shown!.single['id'], 'b1');
      container.dispose();
    });
  });

  test('a server refusal is not mistaken for being offline', () async {
    final container = containerFor('u1');
    await expectLater(
      container.read(offlineCacheProvider).rows('bookings', () => Future.error(StateError('denied'))),
      throwsStateError,
    );
    expect(container.read(connectionProvider).online, isTrue);
  });

  test('coming back online counts a reconnect; signing out wipes saved data', () async {
    final container = containerFor('u1');
    final cache = container.read(offlineCacheProvider);
    await cache.rows('bookings', () async => [
          {'id': 'b1'},
        ]);
    await cache.rows('bookings', offline);

    // What the periodic connection check does once it gets an answer.
    container.read(connectionProvider.notifier).reportOnline();
    expect(container.read(connectionProvider).reconnects, 1);
    expect(await container.read(offlineCacheProvider).rows('bookings', () async => []), isEmpty);

    await OfflineCache.clear();
    await expectLater(container.read(offlineCacheProvider).rows('bookings', offline), throwsA(isA<http.ClientException>()));
  });
}
