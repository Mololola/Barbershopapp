import 'package:flutter/material.dart';

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

class Business {
  const Business({
    required this.id,
    required this.ownerId,
    required this.name,
    this.phone,
    required this.currency,
    this.logoUrl,
    this.isSetupComplete = false,
  });

  final String id;
  final String ownerId;
  final String name;
  final String? phone;
  final String currency;
  final String? logoUrl;

  /// False until the owner finishes the onboarding wizard (details, a
  /// service, a staff member) — the router keeps them in it until then.
  final bool isSetupComplete;

  factory Business.fromRow(Map<String, dynamic> row) {
    return Business(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      name: row['name'] as String,
      phone: row['phone'] as String?,
      currency: row['currency'] as String,
      logoUrl: row['logo_url'] as String?,
      isSetupComplete: row['setup_completed_at'] != null,
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

class OpeningHours {
  const OpeningHours({
    required this.dayOfWeek,
    required this.isClosed,
    this.openTime,
    this.closeTime,
  });

  /// 0 = Monday .. 6 = Sunday
  final int dayOfWeek;
  final bool isClosed;
  final TimeOfDay? openTime;
  final TimeOfDay? closeTime;

  /// Mirrors the opening_hours_valid_range DB constraint.
  bool get hasValidRange {
    if (isClosed) return true;
    final open = openTime;
    final close = closeTime;
    if (open == null || close == null) return false;
    return close.hour * 60 + close.minute > open.hour * 60 + open.minute;
  }

  static const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  OpeningHours copyWith({bool? isClosed, TimeOfDay? openTime, TimeOfDay? closeTime}) {
    return OpeningHours(
      dayOfWeek: dayOfWeek,
      isClosed: isClosed ?? this.isClosed,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
    );
  }

  factory OpeningHours.fromRow(Map<String, dynamic> row) {
    return OpeningHours(
      dayOfWeek: row['day_of_week'] as int,
      isClosed: row['is_closed'] as bool,
      openTime: timeOfDayFromSql(row['open_time'] as String?),
      closeTime: timeOfDayFromSql(row['close_time'] as String?),
    );
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
  });

  final String? id;
  final String businessId;
  final String name;
  final int priceCents;
  final int durationMinutes;
  final bool isActive;

  double get priceInMajorUnits => priceCents / 100;

  factory Service.fromRow(Map<String, dynamic> row) {
    return Service(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      name: row['name'] as String,
      priceCents: row['price_cents'] as int,
      durationMinutes: row['duration_minutes'] as int,
      isActive: row['is_active'] as bool,
    );
  }
}

class CostItem {
  const CostItem({
    this.id,
    required this.businessId,
    required this.label,
    required this.amountCents,
  });

  final String? id;
  final String businessId;
  final String label;
  final int amountCents;

  double get amountInMajorUnits => amountCents / 100;

  factory CostItem.fromRow(Map<String, dynamic> row) {
    return CostItem(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      label: row['label'] as String,
      amountCents: row['amount_cents'] as int,
    );
  }
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
