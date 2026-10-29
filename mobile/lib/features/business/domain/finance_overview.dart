import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import 'business.dart';

/// GET /businesses/{id}/finance — mirrors backend/app/api/finance.py. All
/// the arithmetic happens server-side; this is display data.

DateTime _date(Object? value) => DateTime.parse(value as String);

/// "September 2026" (or "Sep" when [short]), capitalised (Spanish writes
/// month names in lower case).
String monthLabel(AppLocalizations l10n, DateTime month, {bool short = false}) {
  final label = (short ? DateFormat.MMM(l10n.localeName) : DateFormat.yMMMM(l10n.localeName)).format(month);
  return label[0].toUpperCase() + label.substring(1);
}

/// "£1,240" for whole amounts, "£12.50" otherwise; negative as "-£85".
String formatMoney(int cents, String currency) {
  final symbol = currencySymbol(currency);
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final whole = (abs ~/ 100).toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return abs % 100 == 0 ? '$sign$symbol$whole' : '$sign$symbol$whole.${(abs % 100).toString().padLeft(2, '0')}';
}

class FinanceMonth {
  const FinanceMonth({
    required this.month,
    required this.bookingRevenueCents,
    required this.otherIncomeCents,
    required this.revenueCents,
    required this.costsCents,
    required this.netCents,
    required this.completedBookings,
  });

  final DateTime month;
  final int bookingRevenueCents;
  final int otherIncomeCents;
  final int revenueCents;
  final int costsCents;
  final int netCents;
  final int completedBookings;

  factory FinanceMonth.fromJson(Map<String, dynamic> json) => FinanceMonth(
        month: _date(json['month']),
        bookingRevenueCents: json['booking_revenue_cents'] as int,
        otherIncomeCents: json['other_income_cents'] as int,
        revenueCents: json['revenue_cents'] as int,
        costsCents: json['costs_cents'] as int,
        netCents: json['net_cents'] as int,
        completedBookings: json['completed_bookings'] as int,
      );
}

class FinanceSummary extends FinanceMonth {
  const FinanceSummary({
    required super.month,
    required super.bookingRevenueCents,
    required super.otherIncomeCents,
    required super.revenueCents,
    required super.costsCents,
    required super.netCents,
    required super.completedBookings,
    required this.averageTicketCents,
    required this.bookingsToBreakEven,
  });

  final int averageTicketCents;

  /// Null once the month is in profit.
  final int? bookingsToBreakEven;

  factory FinanceSummary.fromJson(Map<String, dynamic> json) {
    final m = FinanceMonth.fromJson(json);
    return FinanceSummary(
      month: m.month,
      bookingRevenueCents: m.bookingRevenueCents,
      otherIncomeCents: m.otherIncomeCents,
      revenueCents: m.revenueCents,
      costsCents: m.costsCents,
      netCents: m.netCents,
      completedBookings: m.completedBookings,
      averageTicketCents: json['average_ticket_cents'] as int,
      bookingsToBreakEven: json['bookings_to_break_even'] as int?,
    );
  }
}

class PremiumState {
  const PremiumState({required this.hasPremium, this.trialEndsAt, required this.trialUsed, required this.subscribed});

  final bool hasPremium;
  final DateTime? trialEndsAt;
  final bool trialUsed;
  final bool subscribed;

  bool get onTrial => trialEndsAt != null && !subscribed;

  factory PremiumState.fromJson(Map<String, dynamic> json) => PremiumState(
        hasPremium: json['has_premium'] as bool,
        trialEndsAt: json['trial_ends_at'] == null ? null : _date(json['trial_ends_at']),
        trialUsed: json['trial_used'] as bool,
        subscribed: json['subscribed'] as bool,
      );
}

class Forecast {
  const Forecast({
    required this.projectedRevenueCents,
    required this.projectedNetCents,
    required this.confirmedUpcomingCents,
    this.breakEvenDay,
    required this.alreadyBrokenEven,
  });

  final int projectedRevenueCents;
  final int projectedNetCents;
  final int confirmedUpcomingCents;
  final DateTime? breakEvenDay;
  final bool alreadyBrokenEven;

  factory Forecast.fromJson(Map<String, dynamic> json) => Forecast(
        projectedRevenueCents: json['projected_revenue_cents'] as int,
        projectedNetCents: json['projected_net_cents'] as int,
        confirmedUpcomingCents: json['confirmed_upcoming_cents'] as int,
        breakEvenDay: json['break_even_day'] == null ? null : _date(json['break_even_day']),
        alreadyBrokenEven: json['already_broken_even'] as bool,
      );
}

class HeatCell {
  const HeatCell({required this.weekday, required this.hour, this.utilisation});

  /// 0 = Monday.
  final int weekday;
  final int hour;
  final double? utilisation;

  factory HeatCell.fromJson(Map<String, dynamic> json) => HeatCell(
        weekday: json['weekday'] as int,
        hour: json['hour'] as int,
        utilisation: (json['utilisation'] as num?)?.toDouble(),
      );
}

class BarberStats {
  const BarberStats({
    required this.name,
    required this.bookings,
    required this.revenueCents,
    this.utilisation,
    this.averageRating,
  });

  final String name;
  final int bookings;
  final int revenueCents;
  final double? utilisation;
  final double? averageRating;

  factory BarberStats.fromJson(Map<String, dynamic> json) => BarberStats(
        name: json['name'] as String,
        bookings: json['bookings'] as int,
        revenueCents: json['revenue_cents'] as int,
        utilisation: (json['utilisation'] as num?)?.toDouble(),
        averageRating: (json['average_rating'] as num?)?.toDouble(),
      );
}

class ServiceStats {
  const ServiceStats({
    required this.name,
    required this.bookings,
    required this.revenueCents,
    required this.share,
    required this.previousBookings,
  });

  final String name;
  final int bookings;
  final int revenueCents;
  final double share;
  final int previousBookings;

  factory ServiceStats.fromJson(Map<String, dynamic> json) => ServiceStats(
        name: json['name'] as String,
        bookings: json['bookings'] as int,
        revenueCents: json['revenue_cents'] as int,
        share: (json['share'] as num).toDouble(),
        previousBookings: json['previous_bookings'] as int,
      );
}

class AtRiskCustomer {
  const AtRiskCustomer({
    required this.username,
    required this.visits,
    required this.lastVisit,
    required this.usualGapDays,
    required this.daysSince,
  });

  final String username;
  final int visits;
  final DateTime lastVisit;
  final int usualGapDays;
  final int daysSince;

  factory AtRiskCustomer.fromJson(Map<String, dynamic> json) => AtRiskCustomer(
        username: json['username'] as String,
        visits: json['visits'] as int,
        lastVisit: _date(json['last_visit']),
        usualGapDays: json['usual_gap_days'] as int,
        daysSince: json['days_since'] as int,
      );
}

class CustomerStats {
  const CustomerStats({
    required this.customersLast30Days,
    required this.newLast30Days,
    required this.returningLast30Days,
    this.returnRate,
    required this.atRisk,
  });

  final int customersLast30Days;
  final int newLast30Days;
  final int returningLast30Days;
  final double? returnRate;
  final List<AtRiskCustomer> atRisk;

  factory CustomerStats.fromJson(Map<String, dynamic> json) => CustomerStats(
        customersLast30Days: json['customers_last_30_days'] as int,
        newLast30Days: json['new_last_30_days'] as int,
        returningLast30Days: json['returning_last_30_days'] as int,
        returnRate: (json['return_rate'] as num?)?.toDouble(),
        atRisk: [for (final c in json['at_risk'] as List) AtRiskCustomer.fromJson(c as Map<String, dynamic>)],
      );
}

class Suggestion {
  const Suggestion({
    required this.kind,
    required this.title,
    required this.detail,
    required this.monthlyGainCents,
    required this.assumptions,
  });

  final String kind;
  final String title;
  final String detail;
  final int monthlyGainCents;
  final String assumptions;

  factory Suggestion.fromJson(Map<String, dynamic> json) => Suggestion(
        kind: json['kind'] as String,
        title: json['title'] as String,
        detail: json['detail'] as String,
        monthlyGainCents: json['monthly_gain_cents'] as int,
        assumptions: json['assumptions'] as String,
      );
}

class PremiumInsights {
  const PremiumInsights({
    this.forecast,
    required this.history,
    this.utilisation,
    required this.heatmap,
    required this.barbers,
    required this.services,
    required this.customers,
    required this.suggestions,
    required this.averageTicketCents,
  });

  final Forecast? forecast;
  final List<FinanceMonth> history;
  final double? utilisation;
  final List<HeatCell> heatmap;
  final List<BarberStats> barbers;
  final List<ServiceStats> services;
  final CustomerStats customers;
  final List<Suggestion> suggestions;
  final int averageTicketCents;

  factory PremiumInsights.fromJson(Map<String, dynamic> json) => PremiumInsights(
        forecast: json['forecast'] == null ? null : Forecast.fromJson(json['forecast'] as Map<String, dynamic>),
        history: [for (final m in json['history'] as List) FinanceMonth.fromJson(m as Map<String, dynamic>)],
        utilisation: (json['utilisation'] as num?)?.toDouble(),
        heatmap: [for (final c in json['heatmap'] as List) HeatCell.fromJson(c as Map<String, dynamic>)],
        barbers: [for (final b in json['barbers'] as List) BarberStats.fromJson(b as Map<String, dynamic>)],
        services: [for (final s in json['services'] as List) ServiceStats.fromJson(s as Map<String, dynamic>)],
        customers: CustomerStats.fromJson(json['customers'] as Map<String, dynamic>),
        suggestions: [for (final s in json['suggestions'] as List) Suggestion.fromJson(s as Map<String, dynamic>)],
        averageTicketCents: json['average_ticket_cents'] as int,
      );
}

class FinanceOverview {
  const FinanceOverview({
    required this.currency,
    required this.month,
    required this.isCurrentMonth,
    required this.premiumState,
    required this.summary,
    this.premium,
  });

  final String currency;
  final DateTime month;
  final bool isCurrentMonth;
  final PremiumState premiumState;
  final FinanceSummary summary;

  /// Null without premium — the backend doesn't send it at all.
  final PremiumInsights? premium;

  factory FinanceOverview.fromJson(Map<String, dynamic> json) => FinanceOverview(
        currency: json['currency'] as String,
        month: _date(json['month']),
        isCurrentMonth: json['is_current_month'] as bool,
        premiumState: PremiumState.fromJson(json['premium_state'] as Map<String, dynamic>),
        summary: FinanceSummary.fromJson(json['summary'] as Map<String, dynamic>),
        premium: json['premium'] == null ? null : PremiumInsights.fromJson(json['premium'] as Map<String, dynamic>),
      );
}

/// The what-if simulator: a month's profit if prices move by [priceChange]
/// and the number of bookings by [bookingChange] (both fractions, e.g.
/// 0.10 = +10%). Costs and other income stay as they are.
int simulateNet({
  required int bookingRevenueCents,
  required int otherIncomeCents,
  required int costsCents,
  required double priceChange,
  required double bookingChange,
}) {
  return (bookingRevenueCents * (1 + priceChange) * (1 + bookingChange)).round() + otherIncomeCents - costsCents;
}
