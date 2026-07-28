import '../../customer/domain/booking.dart';
import 'business.dart';

class ServiceRevenueLine {
  const ServiceRevenueLine({required this.serviceName, required this.count, required this.amountCents});

  final String serviceName;
  final int count;
  final int amountCents;
}

class FinanceSummary {
  const FinanceSummary({
    required this.revenueCents,
    required this.costsCents,
    required this.netCents,
    required this.completedBookingsCount,
    required this.uniqueCustomersCount,
    required this.avgVisitsPerCustomer,
    required this.revenueByService,
    required this.recommendations,
  });

  final int revenueCents;
  final int costsCents;
  final int netCents;
  final int completedBookingsCount;
  final int uniqueCustomersCount;
  final double avgVisitsPerCustomer;
  final List<ServiceRevenueLine> revenueByService;
  final List<String> recommendations;

  bool get hasBrokenEven => netCents >= 0;
}

/// Below this many active customers, one customer's visit pattern can make
/// a frequency tier look "dominant" by accident.
const _minCustomersForFrequencySegmentation = 5;

/// Below this many completed bookings, the service-mix insights (combo,
/// underbooked service, quietest day) are too noisy to be worth surfacing.
const _minBookingsForServiceInsights = 5;

/// Minimum customers who must have booked both services on separate visits
/// before suggesting a bundle — avoids recommending a combo off 1-2
/// coincidences.
const _minComboCustomers = 3;

/// A service's share of this month's bookings below this counts as
/// "underbooked" relative to an even split across whatever's on offer.
const _underbookedShareThreshold = 0.15;

const _weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// Deterministic, no I/O — this is the one place in the finance feature
/// that needs to be trustworthy above all else, so it's kept as a pure
/// function that's exhaustively unit-testable without a database or app.
FinanceSummary computeFinanceSummary({
  required List<Booking> bookings,
  required List<Service> services,
  required List<CostItem> costItems,
  required DateTime monthStart,
  required DateTime monthEnd,
  required String currencySymbol,
}) {
  final priceByServiceId = {
    for (final service in services)
      if (service.id != null) service.id!: service.priceCents,
  };
  final nameByServiceId = {
    for (final service in services)
      if (service.id != null) service.id!: service.name,
  };

  final completed = bookings.where((booking) {
    return booking.status == BookingStatus.completed &&
        !booking.startTime.isBefore(monthStart) &&
        booking.startTime.isBefore(monthEnd);
  }).toList();

  final revenueCents = completed.fold<int>(
    0,
    (sum, booking) => sum + (priceByServiceId[booking.serviceId] ?? 0),
  );
  final costsCents = costItems.fold<int>(0, (sum, item) => sum + item.amountCents);
  final netCents = revenueCents - costsCents;

  final countByServiceId = <String, int>{};
  final amountByServiceId = <String, int>{};
  for (final booking in completed) {
    countByServiceId[booking.serviceId] = (countByServiceId[booking.serviceId] ?? 0) + 1;
    amountByServiceId[booking.serviceId] =
        (amountByServiceId[booking.serviceId] ?? 0) + (priceByServiceId[booking.serviceId] ?? 0);
  }
  final revenueByService = countByServiceId.keys
      .map((serviceId) => ServiceRevenueLine(
            serviceName: nameByServiceId[serviceId] ?? 'Other services',
            count: countByServiceId[serviceId]!,
            amountCents: amountByServiceId[serviceId]!,
          ))
      .toList()
    ..sort((a, b) => b.amountCents.compareTo(a.amountCents));

  final uniqueCustomerIds = completed.map((booking) => booking.customerId).toSet();
  final avgVisitsPerCustomer =
      uniqueCustomerIds.isEmpty ? 0.0 : completed.length / uniqueCustomerIds.length;

  final recommendations = <String>[];
  if (completed.isEmpty) {
    recommendations.add('No completed bookings yet this month — nothing to calculate yet.');
  } else {
    if (netCents >= 0) {
      recommendations.add(
        '$currencySymbol${(netCents / 100).toStringAsFixed(2)} above break-even this month.',
      );
    } else {
      recommendations.add(
        '$currencySymbol${(-netCents / 100).toStringAsFixed(2)} short of breaking even this month.',
      );
      final target = _breakEvenTargetRecommendation(-netCents, revenueCents, completed.length);
      if (target != null) recommendations.add(target);
    }

    final frequencyTip = _frequencySegmentRecommendation(completed);
    if (frequencyTip != null) recommendations.add(frequencyTip);

    final comboTip = _serviceComboRecommendation(completed, nameByServiceId);
    if (comboTip != null) recommendations.add(comboTip);

    final underbookedTip = _underbookedServiceRecommendation(completed, services, countByServiceId);
    if (underbookedTip != null) recommendations.add(underbookedTip);

    final quietDayTip = _quietestDayRecommendation(completed);
    if (quietDayTip != null) recommendations.add(quietDayTip);
  }

  return FinanceSummary(
    revenueCents: revenueCents,
    costsCents: costsCents,
    netCents: netCents,
    completedBookingsCount: completed.length,
    uniqueCustomersCount: uniqueCustomerIds.length,
    avgVisitsPerCustomer: avgVisitsPerCustomer,
    revenueByService: revenueByService,
    recommendations: recommendations,
  );
}

/// A literal number to aim for, not just a status — how many more haircuts
/// at the current average price (or what price rise) would close the gap.
String? _breakEvenTargetRecommendation(int shortfallCents, int revenueCents, int completedCount) {
  if (revenueCents <= 0) return null;
  final avgRevenuePerBooking = revenueCents / completedCount;
  final extraBookingsNeeded = (shortfallCents / avgRevenuePerBooking).ceil();
  final priceIncreasePercent = (shortfallCents / revenueCents) * 100;
  return 'Roughly $extraBookingsNeeded more haircuts at your current average price, or a '
      '${priceIncreasePercent.toStringAsFixed(0)}% price increase, would close the gap this month.';
}

/// Buckets customers by visits this month and matches a nudge to whichever
/// tier is most common — the spec's own example ("3 haircuts for the price
/// of 2") is the tier-2 case; tier-1 and tier-3+ get their own angle.
String? _frequencySegmentRecommendation(List<Booking> completed) {
  final visitsByCustomer = <String, int>{};
  for (final booking in completed) {
    visitsByCustomer[booking.customerId] = (visitsByCustomer[booking.customerId] ?? 0) + 1;
  }
  if (visitsByCustomer.length < _minCustomersForFrequencySegmentation) return null;

  var tier1 = 0, tier2 = 0, tier3Plus = 0;
  for (final visits in visitsByCustomer.values) {
    if (visits <= 1) {
      tier1++;
    } else if (visits == 2) {
      tier2++;
    } else {
      tier3Plus++;
    }
  }

  if (tier1 >= tier2 && tier1 >= tier3Plus) {
    return 'Most customers visit once a month — a half-price second cut this month could turn '
        'one-time visitors into repeat customers.';
  }
  if (tier2 >= tier3Plus) {
    return 'Most customers already visit twice a month — a discounted third cut (e.g. 3 haircuts '
        'for the price of 2) could push them to a third visit.';
  }
  return 'Most customers already visit 3+ times a month — a referral reward or a premium add-on '
      'service is likely to grow revenue further than another frequency discount.';
}

/// Finds the pair of services most often booked separately by the same
/// customer this month — a candidate for bundling into a discounted combo.
String? _serviceComboRecommendation(List<Booking> completed, Map<String, String> nameByServiceId) {
  if (completed.length < _minBookingsForServiceInsights) return null;

  final servicesByCustomer = <String, Set<String>>{};
  for (final booking in completed) {
    (servicesByCustomer[booking.customerId] ??= {}).add(booking.serviceId);
  }

  final pairCounts = <String, int>{};
  for (final serviceIds in servicesByCustomer.values) {
    if (serviceIds.length < 2) continue;
    final sorted = serviceIds.toList()..sort();
    for (var i = 0; i < sorted.length; i++) {
      for (var j = i + 1; j < sorted.length; j++) {
        final key = '${sorted[i]}|${sorted[j]}';
        pairCounts[key] = (pairCounts[key] ?? 0) + 1;
      }
    }
  }
  if (pairCounts.isEmpty) return null;

  final topEntry = pairCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);
  if (topEntry.value < _minComboCustomers) return null;

  final ids = topEntry.key.split('|');
  final nameA = nameByServiceId[ids[0]] ?? 'Other services';
  final nameB = nameByServiceId[ids[1]] ?? 'Other services';
  return '${topEntry.value} customers booked both $nameA and $nameB on separate visits this month — '
      'bundling them into a combo could increase revenue per visit.';
}

/// Flags the highest-priced service if it's rarely chosen relative to the
/// rest of the lineup — a candidate for a discount or a feature spot.
String? _underbookedServiceRecommendation(
  List<Booking> completed,
  List<Service> services,
  Map<String, int> countByServiceId,
) {
  if (completed.length < _minBookingsForServiceInsights || services.length < 2) return null;

  final highestPriced = services.reduce((a, b) => a.priceCents >= b.priceCents ? a : b);
  if (highestPriced.id == null) return null;
  final share = (countByServiceId[highestPriced.id] ?? 0) / completed.length;
  if (share >= _underbookedShareThreshold) return null;

  return '${highestPriced.name} is one of your highest-priced services but made up only '
      '${(share * 100).toStringAsFixed(0)}% of bookings this month — a discount or feature spot '
      'could boost its uptake.';
}

/// Flags the weekday with the fewest completed bookings, when there's
/// enough spread across days to make the comparison meaningful.
String? _quietestDayRecommendation(List<Booking> completed) {
  if (completed.length < _minBookingsForServiceInsights) return null;

  final countByWeekday = <int, int>{};
  for (final booking in completed) {
    countByWeekday[booking.startTime.weekday] = (countByWeekday[booking.startTime.weekday] ?? 0) + 1;
  }
  if (countByWeekday.length < 3) return null;

  final quietest = countByWeekday.entries.reduce((a, b) => a.value <= b.value ? a : b);
  final busiest = countByWeekday.entries.reduce((a, b) => a.value >= b.value ? a : b);
  if (quietest.value == busiest.value) return null;

  final dayName = _weekdayNames[quietest.key - 1];
  return '$dayName is your quietest day — an off-peak discount could help fill that time.';
}
