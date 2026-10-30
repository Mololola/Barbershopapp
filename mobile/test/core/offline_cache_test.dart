import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  Future<List<Map<String, dynamic>>> rowsOf(String id) async => [
        {'id': id},
      ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await OfflineCache.clear();
  });

  test('a screen opens with its saved copy, refreshed in the background; later loads go to the server', () async {
    final container = containerFor('u1');
    await container.read(offlineCacheProvider).rows('bookings', () => rowsOf('b1'));

    // Opening it again: the saved copy at once, while the server has news.
    final shown = await container.read(offlineCacheProvider).rows('bookings', () => rowsOf('b2'));
    expect(shown.single['id'], 'b1');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(container.read(savedDataChangedProvider), 1);

    // After that, e.g. once an action changed something: always the server.
    final later = await container.read(offlineCacheProvider).rows('bookings', () => rowsOf('b3'));
    expect(later.single['id'], 'b3');
  });

  test('offline, the saved copy is shown and the app notices it is offline', () async {
    final container = containerFor('u1');
    await container.read(offlineCacheProvider).rows('bookings', () => rowsOf('b1'));

    expect((await container.read(offlineCacheProvider).rows('bookings', offline)).single['id'], 'b1');
    await pumpEventQueue();
    expect(container.read(connectionProvider).online, isFalse);

    var fetched = false;
    final again = await container.read(offlineCacheProvider).rows('bookings', () {
      fetched = true;
      return rowsOf('b2');
    });
    expect(fetched, isFalse);
    expect(again.single['id'], 'b1');
  });

  test("with nothing saved, or another account's data, the error comes through", () async {
    await containerFor('u1').read(offlineCacheProvider).rows('bookings', () => rowsOf('b1'));

    final other = containerFor('u2').read(offlineCacheProvider);
    await expectLater(other.rows('bookings', offline), throwsA(isA<http.ClientException>()));
  });

  test('a request with no answer gives up after the time limit', () {
    fakeAsync((async) {
      final container = containerFor('u1');
      Object? failure;
      container
          .read(offlineCacheProvider)
          .rows('bookings', () => Completer<List<Map<String, dynamic>>>().future)
          .catchError((Object error) {
        failure = error;
        return <Map<String, dynamic>>[];
      });
      async.elapse(OfflineCache.timeout - const Duration(seconds: 1));
      expect(failure, isNull);
      async.elapse(const Duration(seconds: 1));
      expect(failure, isA<TimeoutException>());
      expect(container.read(connectionProvider).online, isFalse);
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
    await container.read(offlineCacheProvider).rows('bookings', () => rowsOf('b1'));
    await container.read(offlineCacheProvider).rows('bookings', offline);
    await pumpEventQueue();

    // What the periodic connection check does once it gets an answer.
    container.read(connectionProvider.notifier).reportOnline();
    expect(container.read(connectionProvider).reconnects, 1);
    expect(await container.read(offlineCacheProvider).rows('bookings', () async => []), isEmpty);

    await OfflineCache.clear();
    await expectLater(container.read(offlineCacheProvider).rows('bookings', offline), throwsA(isA<http.ClientException>()));
  });
}
