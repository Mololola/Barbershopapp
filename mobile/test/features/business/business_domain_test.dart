import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/business/domain/business.dart';

void main() {
  group('isValidPostcode', () {
    test('accepts UK postcodes with or without the space, any case', () {
      for (final postcode in ['SW1A 1AA', 'M1 1AE', 'm11ae', 'EC1A1BB', 'B33 8TH']) {
        expect(isValidPostcode(postcode, 'GB'), isTrue, reason: postcode);
      }
    });

    test('rejects malformed UK postcodes', () {
      for (final postcode in ['12345', 'SW1A', 'SW1A 1A', 'ABC 123']) {
        expect(isValidPostcode(postcode, 'GB'), isFalse, reason: postcode);
      }
    });

    test('accepts Spanish postcodes in the 01-52 province range only', () {
      expect(isValidPostcode('28013', 'ES'), isTrue);
      expect(isValidPostcode('08001', 'ES'), isTrue);
      expect(isValidPostcode('52001', 'ES'), isTrue);
      expect(isValidPostcode('53001', 'ES'), isFalse);
      expect(isValidPostcode('00123', 'ES'), isFalse);
      expect(isValidPostcode('2801', 'ES'), isFalse);
    });
  });

  test('currencyForCountry maps the launch markets', () {
    expect(currencyForCountry('GB'), 'GBP');
    expect(currencyForCountry('ES'), 'EUR');
  });

  group('OpeningHours.hasValidRange', () {
    const nine = TimeOfDay(hour: 9, minute: 0);
    const six = TimeOfDay(hour: 18, minute: 0);

    test('a closed day is always valid', () {
      expect(const OpeningHours(dayOfWeek: 0, isClosed: true).hasValidRange, isTrue);
    });

    test('an open day needs closing after opening', () {
      expect(const OpeningHours(dayOfWeek: 0, isClosed: false, openTime: nine, closeTime: six).hasValidRange, isTrue);
      expect(const OpeningHours(dayOfWeek: 0, isClosed: false, openTime: six, closeTime: nine).hasValidRange, isFalse);
      expect(const OpeningHours(dayOfWeek: 0, isClosed: false, openTime: nine, closeTime: nine).hasValidRange, isFalse);
      expect(const OpeningHours(dayOfWeek: 0, isClosed: false, openTime: nine).hasValidRange, isFalse);
    });
  });

  test('Business.isSetupComplete follows setup_completed_at', () {
    final row = {'id': 'b', 'owner_id': 'o', 'name': 'N', 'currency': 'GBP'};
    expect(Business.fromRow(row).isSetupComplete, isFalse);
    expect(Business.fromRow({...row, 'setup_completed_at': '2026-09-24T10:00:00Z'}).isSetupComplete, isTrue);
  });

  group('OpeningHours with a break', () {
    const nine = TimeOfDay(hour: 9, minute: 0);
    const eightPm = TimeOfDay(hour: 20, minute: 0);
    const open = OpeningHours(dayOfWeek: 0, isClosed: false, openTime: nine, closeTime: eightPm);

    test('a break strictly inside opening hours is valid', () {
      expect(open.withBreak(const TimeOfDay(hour: 13, minute: 30), const TimeOfDay(hour: 16, minute: 0)).hasValidRange,
          isTrue);
    });

    test('a break outside, touching, inverted or half-set is invalid', () {
      expect(open.withBreak(const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 10, minute: 0)).hasValidRange,
          isFalse);
      expect(open.withBreak(nine, const TimeOfDay(hour: 10, minute: 0)).hasValidRange, isFalse);
      expect(open.withBreak(const TimeOfDay(hour: 16, minute: 0), const TimeOfDay(hour: 13, minute: 0)).hasValidRange,
          isFalse);
      expect(open.withBreak(const TimeOfDay(hour: 13, minute: 0), null).hasValidRange, isFalse);
    });

    test('copyWith keeps the break; withBreak(null, null) removes it', () {
      final withBreak = open.withBreak(const TimeOfDay(hour: 13, minute: 0), const TimeOfDay(hour: 14, minute: 0));
      expect(withBreak.copyWith(closeTime: const TimeOfDay(hour: 19, minute: 0)).hasBreak, isTrue);
      expect(withBreak.withBreak(null, null).hasBreak, isFalse);
    });

    test('a closed day is stored without its break', () {
      final closed = open
          .withBreak(const TimeOfDay(hour: 13, minute: 0), const TimeOfDay(hour: 14, minute: 0))
          .copyWith(isClosed: true);
      expect(closed.toRow()['break_start'], isNull);
      expect(closed.toRow()['break_end'], isNull);
    });
  });

  test('timeZoneForLocation: UK, mainland Spain, Canary Islands', () {
    expect(timeZoneForLocation('GB', 'L7 3ET'), 'Europe/London');
    expect(timeZoneForLocation('ES', '28013'), 'Europe/Madrid');
    expect(timeZoneForLocation('ES', '35001'), 'Atlantic/Canary');
    expect(timeZoneForLocation('ES', '38001'), 'Atlantic/Canary');
  });

  test('OpeningHours.fullWeek fills unsaved days as closed', () {
    final week = OpeningHours.fullWeek([const OpeningHours(dayOfWeek: 2, isClosed: false)]);
    expect(week, hasLength(7));
    expect(week[2].isClosed, isFalse);
    expect(week.where((day) => day.isClosed), hasLength(6));
    expect(OpeningHours.fullWeek([]).where((day) => !day.isClosed), hasLength(6));
  });
}
