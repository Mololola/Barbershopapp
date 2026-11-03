import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/business/application/business_controller.dart';
import 'package:mobile/features/business/presentation/auto_completed_check_card.dart';
import 'package:mobile/features/customer/application/booking_controller.dart';
import 'package:mobile/features/customer/data/booking_api_client.dart';
import 'package:mobile/features/customer/domain/booking.dart';
import 'package:mobile/l10n/app_localizations.dart';

final _yesterday = DateTime.now().subtract(const Duration(days: 1));

Booking _booking(String id, String customer) => Booking(
      id: id,
      businessId: 'shop',
      workerId: 'w1',
      serviceId: 's1',
      customerId: 'c1',
      startTime: _yesterday,
      endTime: _yesterday.add(const Duration(minutes: 30)),
      status: BookingStatus.completed,
      customerName: customer,
    );

/// Answered bookings leave [toCheck], as they do on the server.
class _FakeApi extends Fake implements BookingApiClient {
  _FakeApi(this.toCheck);

  final List<Booking> toCheck;
  final calls = <String>[];

  Booking _answer(String call, String bookingId) {
    calls.add('$call $bookingId');
    toCheck.removeWhere((b) => b.id == bookingId);
    return _booking(bookingId, '');
  }

  @override
  Future<Booking> completeBooking(String bookingId) async => _answer('happened', bookingId);

  @override
  Future<Booking> markNoShow(String bookingId) async => _answer('no-show', bookingId);
}

Future<_FakeApi> _pump(WidgetTester tester, List<Booking> toCheck) async {
  final api = _FakeApi([...toCheck]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      autoCompletedToCheckProvider.overrideWith((ref) async => [...api.toCheck]),
      businessBookingsProvider.overrideWith((ref) async => []),
      bookingApiClientProvider.overrideWithValue(api),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: AutoCompletedCheckCard()),
    ),
  ));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('lists each auto-completed booking to check', (tester) async {
    await _pump(tester, [_booking('b1', 'jordan'), _booking('b2', 'sam')]);

    expect(find.text('2 bookings were marked done automatically'), findsOneWidget);
    expect(find.textContaining('jordan'), findsOneWidget);
    expect(find.textContaining('sam'), findsOneWidget);
  });

  testWidgets('"No-show" corrects it and it leaves the list', (tester) async {
    final api = await _pump(tester, [_booking('b1', 'jordan'), _booking('b2', 'sam')]);

    await tester.tap(find.text('No-show').first);
    await tester.pumpAndSettle();

    expect(api.calls, ['no-show b1']);
    expect(find.textContaining('jordan'), findsNothing);
    expect(find.text('1 booking was marked done automatically'), findsOneWidget);
  });

  testWidgets('"It happened" confirms it', (tester) async {
    final api = await _pump(tester, [_booking('b1', 'jordan')]);

    await tester.tap(find.text('It happened'));
    await tester.pumpAndSettle();

    expect(api.calls, ['happened b1']);
    expect(find.textContaining('marked done automatically'), findsNothing);
  });

  testWidgets('nothing to check, no card', (tester) async {
    await _pump(tester, []);

    expect(find.byType(Card), findsNothing);
  });
}
