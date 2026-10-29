import 'package:flutter/material.dart';

import '../../../core/l10n.dart';

const supportedCurrencies = ['GBP', 'EUR', 'USD'];

const _currencySymbols = {'GBP': '£', 'EUR': '€', 'USD': '\$'};

String currencySymbol(String currencyCode) => _currencySymbols[currencyCode] ?? '$currencyCode ';

/// ISO 3166-1 alpha-2 codes for the launch markets — a location's country
/// is stored as this code.
const supportedCountries = {'GB': 'United Kingdom', 'ES': 'Spain'};

const _countryCurrencies = {'GB': 'GBP', 'ES': 'EUR'};

String currencyForCountry(String countryCode) => _countryCurrencies[countryCode] ?? supportedCurrencies.first;

final _postcodePatterns = {
  // Outward code + inward code, space optional: "SW1A 1AA", "m11ae".
  'GB': RegExp(r'^[A-Z]{1,2}[0-9][A-Z0-9]? ?[0-9][A-Z]{2}$', caseSensitive: false),
  // 5 digits, first two a province code 01-52.
  'ES': RegExp(r'^(0[1-9]|[1-4][0-9]|5[0-2])[0-9]{3}$'),
};

bool isValidPostcode(String postcode, String countryCode) {
  final pattern = _postcodePatterns[countryCode];
  return pattern == null || pattern.hasMatch(postcode.trim());
}

/// IANA zone a shop's opening hours are wall-clock times in — must be one
/// the businesses_time_zone_check DB constraint allows. The Canary Islands
/// (postcodes 35xxx, 38xxx) run an hour behind mainland Spain.
String timeZoneForLocation(String countryCode, String postcode) {
  if (countryCode == 'ES') {
    final province = postcode.trim().length >= 2 ? postcode.trim().substring(0, 2) : '';
    return province == '35' || province == '38' ? 'Atlantic/Canary' : 'Europe/Madrid';
  }
  return 'Europe/London';
}

class Business {
  const Business({
    required this.id,
    required this.ownerId,
    required this.name,
    this.phone,
    required this.currency,
    this.logoUrl,
    this.coverUrl,
    this.brandColor,
    this.referredByCode,
    this.isSetupComplete = false,
    this.createdAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String? phone;
  final String currency;
  final String? logoUrl;
  final String? coverUrl;

  /// "#RRGGBB", or null until chosen — see brandColorOf.
  final String? brandColor;

  /// The referral code entered at signup, if any — fixed after that.
  final String? referredByCode;

  /// False until the owner finishes the onboarding wizard (details, a
  /// service, a staff member) — the router keeps them in it until then.
  final bool isSetupComplete;

  final DateTime? createdAt;

  factory Business.fromRow(Map<String, dynamic> row) {
    return Business(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      name: row['name'] as String,
      phone: row['phone'] as String?,
      currency: row['currency'] as String,
      logoUrl: row['logo_url'] as String?,
      coverUrl: row['cover_url'] as String?,
      brandColor: row['brand_color'] as String?,
      referredByCode: row['referred_by_code'] as String?,
      isSetupComplete: row['setup_completed_at'] != null,
      createdAt: row['created_at'] != null ? DateTime.parse(row['created_at'] as String) : null,
    );
  }
}

class BusinessLocation {
  const BusinessLocation({
    this.id,
    required this.addressLine,
    required this.city,
    required this.postcode,
    required this.country,
  });

  final String? id;
  final String addressLine;
  final String city;
  final String postcode;

  /// ISO 3166-1 alpha-2, one of [supportedCountries].
  final String country;

  String get displayAddress => '$addressLine, $city $postcode';

  factory BusinessLocation.fromRow(Map<String, dynamic> row) {
    return BusinessLocation(
      id: row['id'] as String,
      addressLine: row['address_line'] as String,
      city: row['city'] as String,
      postcode: row['postcode'] as String,
      country: row['country'] as String,
    );
  }

  String get timeZone => timeZoneForLocation(country, postcode);

  Map<String, dynamic> toRow(String businessId) => {
        'business_id': businessId,
        'address_line': addressLine,
        'city': city,
        'postcode': postcode.trim().toUpperCase(),
        'country': country,
      };
}

/// Parses Postgres `time` values ("09:00:00") to/from [TimeOfDay].
TimeOfDay? timeOfDayFromSql(String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

String? timeOfDayToSql(TimeOfDay? value) {
  if (value == null) return null;
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';
}

int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

/// One day of a shop's hours or a worker's schedule, with an optional break
/// (a lunch break, a split "jornada partida") splitting it in two.
class OpeningHours {
  const OpeningHours({
    required this.dayOfWeek,
    required this.isClosed,
    this.openTime,
    this.closeTime,
    this.breakStart,
    this.breakEnd,
  });

  /// 0 = Monday .. 6 = Sunday
  final int dayOfWeek;
  final bool isClosed;
  final TimeOfDay? openTime;
  final TimeOfDay? closeTime;
  final TimeOfDay? breakStart;
  final TimeOfDay? breakEnd;

  bool get hasBreak => breakStart != null && breakEnd != null;

  /// Mirrors the opening_hours_valid_range / worker_schedules_valid_range
  /// DB constraints: closing after opening, and a break (both ends or
  /// neither) strictly inside them.
  bool get hasValidRange {
    if (isClosed) return true;
    final open = openTime;
    final close = closeTime;
    if (open == null || close == null || _minutes(close) <= _minutes(open)) return false;
    final start = breakStart;
    final end = breakEnd;
    if (start == null && end == null) return true;
    if (start == null || end == null) return false;
    return _minutes(start) > _minutes(open) && _minutes(end) > _minutes(start) && _minutes(close) > _minutes(end);
  }

  /// "Closed", "09:00 – 18:00", or "09:00 – 13:30, 16:00 – 20:00".
  String format(BuildContext context, {String? closedLabel}) {
    if (isClosed) return closedLabel ?? context.l10n.closed;
    final open = openTime?.format(context);
    final close = closeTime?.format(context);
    if (!hasBreak) return '$open – $close';
    return '$open – ${breakStart!.format(context)}, ${breakEnd!.format(context)} – $close';
  }

  static const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  OpeningHours copyWith({bool? isClosed, TimeOfDay? openTime, TimeOfDay? closeTime}) {
    return OpeningHours(
      dayOfWeek: dayOfWeek,
      isClosed: isClosed ?? this.isClosed,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      breakStart: breakStart,
      breakEnd: breakEnd,
    );
  }

  /// Separate from [copyWith] because removing the break means setting
  /// both ends to null, which copyWith's `??` can't express.
  OpeningHours withBreak(TimeOfDay? start, TimeOfDay? end) {
    return OpeningHours(
      dayOfWeek: dayOfWeek,
      isClosed: isClosed,
      openTime: openTime,
      closeTime: closeTime,
      breakStart: start,
      breakEnd: end,
    );
  }

  factory OpeningHours.fromRow(Map<String, dynamic> row) {
    return OpeningHours(
      dayOfWeek: row['day_of_week'] as int,
      isClosed: row['is_closed'] as bool,
      openTime: timeOfDayFromSql(row['open_time'] as String?),
      closeTime: timeOfDayFromSql(row['close_time'] as String?),
      breakStart: timeOfDayFromSql(row['break_start'] as String?),
      breakEnd: timeOfDayFromSql(row['break_end'] as String?),
    );
  }

  /// The day's columns for an opening_hours or worker_schedules row — the
  /// caller adds the owning business_id / worker_id.
  Map<String, dynamic> toRow() => {
        'day_of_week': dayOfWeek,
        'is_closed': isClosed,
        'open_time': timeOfDayToSql(openTime),
        'close_time': timeOfDayToSql(closeTime),
        // A closed day keeps no break, or a later re-open would resurrect it.
        'break_start': isClosed ? null : timeOfDayToSql(breakStart),
        'break_end': isClosed ? null : timeOfDayToSql(breakEnd),
      };

  /// The editable 7-day week for stored rows: [defaultWeek] when nothing's
  /// been saved yet, otherwise the saved days with any missing one closed.
  static List<OpeningHours> fullWeek(List<OpeningHours> stored) {
    if (stored.isEmpty) return defaultWeek();
    final byDay = {for (final h in stored) h.dayOfWeek: h};
    return [for (var day = 0; day < 7; day++) byDay[day] ?? OpeningHours(dayOfWeek: day, isClosed: true)];
  }

  static List<OpeningHours> defaultWeek() {
    return List.generate(7, (day) {
      if (day == 6) return OpeningHours(dayOfWeek: day, isClosed: true);
      return OpeningHours(
        dayOfWeek: day,
        isClosed: false,
        openTime: const TimeOfDay(hour: 9, minute: 0),
        closeTime: const TimeOfDay(hour: 18, minute: 0),
      );
    });
  }
}

class Service {
  const Service({
    this.id,
    required this.businessId,
    required this.name,
    required this.priceCents,
    required this.durationMinutes,
    this.isActive = true,
    this.isBasicCut = false,
  });

  final String? id;
  final String businessId;
  final String name;
  final int priceCents;
  final int durationMinutes;
  final bool isActive;

  /// The shop's standard haircut; the subscription is priced from it. Only
  /// ever shown to the owner.
  final bool isBasicCut;

  double get priceInMajorUnits => priceCents / 100;

  factory Service.fromRow(Map<String, dynamic> row) {
    return Service(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      name: row['name'] as String,
      priceCents: row['price_cents'] as int,
      durationMinutes: row['duration_minutes'] as int,
      isActive: row['is_active'] as bool,
      isBasicCut: row['is_basic_cut'] as bool? ?? false,
    );
  }
}

enum CostKind { monthly, oneOff }

/// A business cost: 'monthly' runs from [startsOn] until [endsOn]
/// (inclusive, open-ended if null); 'one-off' belongs to [startsOn]'s month
/// only. Months are their first day. Dated so past months stay accurate.
class CostItem {
  const CostItem({
    this.id,
    required this.businessId,
    required this.label,
    required this.amountCents,
    required this.kind,
    required this.startsOn,
    this.endsOn,
    this.isAutomatic = false,
  });

  final String? id;
  final String businessId;
  final String label;
  final int amountCents;
  final CostKind kind;
  final DateTime startsOn;
  final DateTime? endsOn;

  /// What the shop pays us, kept by the backend from Stripe — not editable.
  final bool isAutomatic;

  bool appliesTo(DateTime month) => kind == CostKind.oneOff
      ? startsOn == month
      : !startsOn.isAfter(month) && (endsOn == null || !month.isAfter(endsOn!));

  static String _wire(CostKind kind) => kind == CostKind.oneOff ? 'one_off' : 'monthly';

  static String dateToSql(DateTime month) =>
      '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-01';

  factory CostItem.fromRow(Map<String, dynamic> row) {
    return CostItem(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      label: row['label'] as String,
      amountCents: row['amount_cents'] as int,
      kind: row['kind'] == 'one_off' ? CostKind.oneOff : CostKind.monthly,
      startsOn: DateTime.parse(row['starts_on'] as String),
      endsOn: row['ends_on'] == null ? null : DateTime.parse(row['ends_on'] as String),
      isAutomatic: row['stripe_subscription_id'] != null,
    );
  }

  Map<String, dynamic> toRow() => {
        'business_id': businessId,
        'label': label,
        'amount_cents': amountCents,
        'kind': _wire(kind),
        'starts_on': dateToSql(startsOn),
      };
}

class Worker {
  const Worker({
    this.id,
    required this.businessId,
    this.businessName,
    required this.name,
    this.profileId,
    this.isActive = true,
  });

  final String? id;
  final String businessId;

  /// Denormalized (see the migration) — lets a worker read who they work for
  /// without needing cross-table RLS access to `businesses`.
  final String? businessName;

  final String name;

  /// Set when this row represents an account-linked worker (vs. staff the
  /// business added manually by name only).
  final String? profileId;

  final bool isActive;

  factory Worker.fromRow(Map<String, dynamic> row) {
    return Worker(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      businessName: row['business_name'] as String?,
      name: row['name'] as String,
      profileId: row['profile_id'] as String?,
      isActive: row['is_active'] as bool,
    );
  }
}
