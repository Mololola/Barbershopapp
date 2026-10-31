import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/business/application/business_controller.dart';
import 'package:mobile/features/business/domain/business.dart';
import 'package:mobile/features/business/domain/mark_done_reminders.dart';
import 'package:mobile/features/business/presentation/mark_done_reminders.dart';
import 'package:mobile/features/customer/application/booking_controller.dart';
import 'package:mobile/features/customer/data/booking_api_client.dart';
import 'package:mobile/features/customer/data/bookings_repository.dart';
import 'package:mobile/features/customer/domain/booking.dart';
import 'package:mobile/l10n/app_localizations.dart';

Booking _endingAt(DateTime end) => Booking(
      id: 'b1',
      businessId: 'shop',
      workerId: 'w1',
      serviceId: 's1',
      customerId: 'c1',
      startTime: end.subtract(const Duration(minutes: 30)),
      endTime: end,
      status: BookingStatus.confirmed,
      customerName: 'jordan',
    );

Booking _ended(Duration ago) => _endingAt(DateTime.now().subtract(ago));

class _FakeBookings extends Fake implements BookingsRepository {
  _FakeBookings(this.waiting);

  final List<Booking> waiting;

  @override
  Future<List<Booking>> fetchBookingsAwaitingDone(String businessId, DateTime now) async => waiting;
}

class _FakeApi extends Fake implements BookingApiClient {
  final calls = <String>[];

  @override
  Future<Booking> completeBooking(String bookingId) async {
    calls.add('done $bookingId');
    return _ended(Duration.zero);
  }

  @override
  Future<Booking> markNoShow(String bookingId) async {
    calls.add('no-show $bookingId');
    return _ended(Duration.zero);
  }
}

void main() {
  group('which reminder is due', () {
    final now = DateTime(2026, 11, 2, 12);

    test('the first goes out as the booking ends, not before', () {
      expect(dueMarkDoneReminder(_endingAt(now.add(const Duration(minutes: 1))), now, null), isNull);
      expect(dueMarkDoneReminder(_endingAt(now), now, null), 0);
    });

    test('then 15 and 30 minutes later, each once', () {
      final booking = _endingAt(now.subtract(const Duration(minutes: 16)));
      expect(dueMarkDoneReminder(booking, now, 0), 1);
      expect(dueMarkDoneReminder(booking, now, 1), isNull);
      expect(dueMarkDoneReminder(_endingAt(now.subtract(const Duration(minutes: 30))), now, 1), 2);
      expect(dueMarkDoneReminder(_endingAt(now.subtract(const Duration(minutes: 90))), now, 2), isNull);
    });

    test('opening the app late shows only the latest reminder', () {
      expect(dueMarkDoneReminder(_endingAt(now.subtract(const Duration(minutes: 40))), now, null), 2);
    });
  });

  Future<_FakeApi> pumpReminders(WidgetTester tester, List<Booking> waiting) async {
    final api = _FakeApi();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentBusinessProvider.overrideWith(
          (ref) async => const Business(id: 'shop', ownerId: 'me', name: 'Shop', currency: 'GBP'),
        ),
        businessBookingsProvider.overrideWith((ref) async => []),
        bookingsRepositoryProvider.overrideWithValue(_FakeBookings(waiting)),
        bookingApiClientProvider.overrideWithValue(api),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MarkDoneReminders(child: Scaffold(body: Text('shop screens'))),
      ),
    ));
    // The business loads, then the first check runs a minute later.
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('a booking that just ended asks to be marked, and "Mark as done" does it', (tester) async {
    final api = await pumpReminders(tester, [_ended(const Duration(minutes: 1))]);

    expect(find.text('Did this booking happen?'), findsOneWidget);
    expect(find.textContaining("jordan's booking"), findsOneWidget);

    await tester.tap(find.text('Mark as done'));
    await tester.pumpAndSettle();
    expect(api.calls, ['done b1']);
    expect(find.text('Did this booking happen?'), findsNothing);
  });

  testWidgets('"No-show" marks it a no-show', (tester) async {
    final api = await pumpReminders(tester, [_ended(const Duration(minutes: 1))]);

    await tester.tap(find.widgetWithText(TextButton, 'No-show'));
    await tester.pumpAndSettle();
    expect(api.calls, ['no-show b1']);
  });

  testWidgets('"Not now" closes it without changing anything, and the shop keeps working', (tester) async {
    final api = await pumpReminders(tester, [_ended(const Duration(minutes: 1))]);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);
    expect(find.text('shop screens'), findsOneWidget);

    // The same reminder isn't repeated on the next check.
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(find.text('Did this booking happen?'), findsNothing);
  });

  testWidgets('nothing waiting, no pop-up', (tester) async {
    await pumpReminders(tester, []);

    expect(find.text('Did this booking happen?'), findsNothing);
  });
}

