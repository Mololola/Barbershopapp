import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/business/domain/business.dart';
import 'package:mobile/features/business/domain/finance_calculator.dart';
import 'package:mobile/features/customer/domain/booking.dart';

void main() {
  final monthStart = DateTime(2026, 7, 1);
  final monthEnd = DateTime(2026, 8, 1);

  const service = Service(id: 'svc-1', businessId: 'biz-1', name: 'Cut', priceCents: 2000, durationMinutes: 30);

  Booking completedBooking({
    required String id,
    required String customerId,
    required DateTime startTime,
    String serviceId = 'svc-1',
  }) {
    return Booking(
      id: id,
      businessId: 'biz-1',
      workerId: 'worker-1',
      serviceId: serviceId,
      customerId: customerId,
      startTime: startTime,
      endTime: startTime.add(const Duration(minutes: 30)),
      status: BookingStatus.completed,
    );
  }

  /// First date in July 2026 that falls on the given weekday (1=Monday..
  /// 7=Sunday) — avoids hardcoding calendar knowledge into the tests.
  DateTime julyDateForWeekday(int weekday) {
    for (var day = 1; day <= 28; day++) {
      final date = DateTime(2026, 7, day);
      if (date.weekday == weekday) return date;
    }
    throw StateError('not found');
  }

  test('above break-even reports the surplus', () {
    final summary = computeFinanceSummary(
      bookings: [
        completedBooking(id: 'b1', customerId: 'c1', startTime: DateTime(2026, 7, 5)),
        completedBooking(id: 'b2', customerId: 'c1', startTime: DateTime(2026, 7, 12)),
        completedBooking(id: 'b3', customerId: 'c2', startTime: DateTime(2026, 7, 20)),
      ],
      services: const [service],
      costItems: const [CostItem(id: 'cost-1', businessId: 'biz-1', label: 'Rent', amountCents: 5000)],
      monthStart: monthStart,
      monthEnd: monthEnd,
      currencySymbol: '£',
    );

    expect(summary.revenueCents, 6000);
    expect(summary.costsCents, 5000);
    expect(summary.netCents, 1000);
    expect(summary.hasBrokenEven, isTrue);
    expect(summary.completedBookingsCount, 3);
    expect(summary.uniqueCustomersCount, 2);
    expect(summary.revenueByService, hasLength(1));
    expect(summary.revenueByService.single.serviceName, 'Cut');
    expect(summary.revenueByService.single.count, 3);
    expect(summary.revenueByService.single.amountCents, 6000);
    expect(summary.recommendations, ['£10.00 above break-even this month.']);
  });

  test('below break-even adds a numeric target, but skips segment tips below the sample threshold', () {
    final summary = computeFinanceSummary(
      bookings: [
        completedBooking(id: 'b1', customerId: 'c1', startTime: DateTime(2026, 7, 5)),
        completedBooking(id: 'b2', customerId: 'c2', startTime: DateTime(2026, 7, 12)),
      ],
      services: const [service],
      costItems: const [CostItem(id: 'cost-1', businessId: 'biz-1', label: 'Rent', amountCents: 10000)],
      monthStart: monthStart,
      monthEnd: monthEnd,
      currencySymbol: '£',
    );

    expect(summary.netCents, -6000);
    expect(summary.hasBrokenEven, isFalse);
    expect(summary.recommendations, [
      '£60.00 short of breaking even this month.',
      'Roughly 3 more haircuts at your current average price, or a 150% price increase, '
          'would close the gap this month.',
    ]);
  });

  test('below break-even target rounds the price-increase percentage', () {
    final summary = computeFinanceSummary(
      bookings: [
        completedBooking(id: 'b1', customerId: 'c1', startTime: DateTime(2026, 7, 1)),
        completedBooking(id: 'b2', customerId: 'c1', startTime: DateTime(2026, 7, 8)),
        completedBooking(id: 'b3', customerId: 'c1', startTime: DateTime(2026, 7, 15)),
      ],
      services: const [service],
      costItems: const [CostItem(id: 'cost-1', businessId: 'biz-1', label: 'Rent', amountCents: 10000)],
      monthStart: monthStart,
      monthEnd: monthEnd,
      currencySymbol: '£',
    );

    expect(summary.netCents, -4000);
    expect(summary.recommendations, [
      '£40.00 short of breaking even this month.',
      'Roughly 2 more haircuts at your current average price, or a 67% price increase, '
          'would close the gap this month.',
    ]);
  });

  test('exact break-even counts as broken even, not short', () {
    final summary = computeFinanceSummary(
      bookings: [completedBooking(id: 'b1', customerId: 'c1', startTime: DateTime(2026, 7, 5))],
      services: const [service],
      costItems: const [CostItem(id: 'cost-1', businessId: 'biz-1', label: 'Rent', amountCents: 2000)],
      monthStart: monthStart,
      monthEnd: monthEnd,
      currencySymbol: '£',
    );

    expect(summary.netCents, 0);
    expect(summary.hasBrokenEven, isTrue);
    expect(summary.recommendations, ['£0.00 above break-even this month.']);
  });

  test('no completed bookings this month reports nothing to calculate yet', () {
    final summary = computeFinanceSummary(
      bookings: [
        // Confirmed (not completed) — excluded.
        Booking(
          id: 'b1',
          businessId: 'biz-1',
          workerId: 'worker-1',
          serviceId: 'svc-1',
          customerId: 'c1',
          startTime: DateTime(2026, 7, 10),
          endTime: DateTime(2026, 7, 10, 0, 30),
          status: BookingStatus.confirmed,
        ),
        // Completed, but last month — excluded.
        completedBooking(id: 'b2', customerId: 'c1', startTime: DateTime(2026, 6, 20)),
      ],
      services: const [service],
      costItems: const [],
      monthStart: monthStart,
      monthEnd: monthEnd,
      currencySymbol: '£',
    );

    expect(summary.completedBookingsCount, 0);
    expect(summary.revenueCents, 0);
    expect(summary.recommendations, ['No completed bookings yet this month — nothing to calculate yet.']);
  });

  test('a booking whose service was since deleted contributes zero revenue instead of throwing', () {
    final summary = computeFinanceSummary(
      bookings: [
        completedBooking(id: 'b1', customerId: 'c1', startTime: DateTime(2026, 7, 5), serviceId: 'deleted-svc'),
      ],
      services: const [service],
      costItems: const [],
      monthStart: monthStart,
      monthEnd: monthEnd,
      currencySymbol: '£',
    );

    expect(summary.revenueCents, 0);
    expect(summary.completedBookingsCount, 1);
    expect(summary.revenueByService.single.serviceName, 'Other services');
    expect(summary.revenueByService.single.amountCents, 0);
  });

  test('revenue breakdown covers multiple services, sorted by amount descending', () {
    const shave = Service(id: 'svc-2', businessId: 'biz-1', name: 'Shave', priceCents: 1000, durationMinutes: 15);
    final summary = computeFinanceSummary(
      bookings: [
        completedBooking(id: 'b1', customerId: 'c1', startTime: DateTime(2026, 7, 5), serviceId: 'svc-2'),
        completedBooking(id: 'b2', customerId: 'c1', startTime: DateTime(2026, 7, 12)),
        completedBooking(id: 'b3', customerId: 'c2', startTime: DateTime(2026, 7, 20)),
      ],
      services: const [service, shave],
      costItems: const [],
      monthStart: monthStart,
      monthEnd: monthEnd,
      currencySymbol: '£',
    );

    expect(summary.revenueByService, hasLength(2));
    expect(summary.revenueByService[0].serviceName, 'Cut');
    expect(summary.revenueByService[0].count, 2);
    expect(summary.revenueByService[0].amountCents, 4000);
    expect(summary.revenueByService[1].serviceName, 'Shave');
    expect(summary.revenueByService[1].count, 1);
    expect(summary.revenueByService[1].amountCents, 1000);
  });

  test('frequency segmentation: mostly-once-a-month customers get the second-cut nudge', () {
    final summary = computeFinanceSummary(
      bookings: [
        for (var i = 0; i < 5; i++)
          completedBooking(id: 'b$i', customerId: 'c$i', startTime: DateTime(2026, 7, 6)),
      ],
      services: const [service],
      costItems: const [],
      monthStart: monthStart,
      monthEnd: monthEnd,
      currencySymbol: '£',
    );

    expect(summary.recommendations, [
      '£100.00 above break-even this month.',
      'Most customers visit once a month — a half-price second cut this month could turn '
          'one-time visitors into repeat customers.',
    ]);
  });

  test('frequency segmentation: mostly-twice-a-month customers get the third-cut nudge', () {
    final bookings = <Booking>[];
    for (var c = 0; c < 5; c++) {
      for (var visit = 0; visit < 2; visit++) {
        bookings.add(completedBooking(id: 'c$c-v$visit', customerId: 'c$c', startTime: DateTime(2026, 7, 6)));
      }
    }
    final summary = computeFinanceSummary(
      bookings: bookings,
      services: const [service],
      costItems: const [],
      monthStart: monthStart,
      monthEnd: monthEnd,
      currencySymbol: '£',
    );

    expect(summary.recommendations, [
      '£200.00 above break-even this month.',
      'Most customers already visit twice a month — a discounted third cut (e.g. 3 haircuts '
          'for the price of 2) could push them to a third visit.',
    ]);
  });

  test('frequency segmentation: mostly-frequent customers get the referral/upsell suggestion', () {
    final bookings = <Booking>[];
    for (var c = 0; c < 5; c++) {
      for (var visit = 0; visit < 3; visit++) {
        bookings.add(completedBooking(id: 'c$c-v$visit', customerId: 'c$c', startTime: DateTime(2026, 7, 6)));
      }
    }
    final summary = computeFinanceSummary(
      bookings: bookings,
      services: const [service],
      costItems: const [],
      monthStart: monthStart,
      monthEnd: monthEnd,
      currencySymbol: '£',
    );

    expect(summary.recommendations, [
      '£300.00 above break-even this month.',
      'Most customers already visit 3+ times a month — a referral reward or a premium add-on '
          'service is likely to grow revenue further than another frequency discount.',
    ]);
  });

  test('service combo: a pair of services booked separately by enough customers is suggested as a bundle', () {
    const shave = Service(id: 'svc-2', businessId: 'biz-1', name: 'Shave', priceCents: 1000, durationMinutes: 15);
    final bookings = <Booking>[];
    for (var c = 0; c < 3; c++) {
      bookings.add(completedBooking(id: 'c$c-cut', customerId: 'c$c', startTime: DateTime(2026, 7, 6)));
      bookings.add(
        completedBooking(id: 'c$c-shave', customerId: 'c$c', startTime: DateTime(2026, 7, 6), serviceId: 'svc-2'),
      );
    }
    final summary = computeFinanceSummary(
      bookings: bookings,
      services: const [service, shave],
      costItems: const [],
      monthStart: monthStart,
      monthEnd: monthEnd,
      currencySymbol: '£',
    );

    expect(summary.recommendations, [
      '£90.00 above break-even this month.',
      '3 customers booked both Cut and Shave on separate visits this month — bundling them into '
          'a combo could increase revenue per visit.',
    ]);
  });

  test('underbooked service: a rarely-chosen premium service is flagged for promotion', () {
    const premium =
        Service(id: 'svc-2', businessId: 'biz-1', name: 'Premium Styling', priceCents: 5000, durationMinutes: 60);
    final bookings = [
      for (var c = 0; c < 10; c++) completedBooking(id: 'cut-$c', customerId: 'c$c', startTime: DateTime(2026, 7, 6)),
      completedBooking(id: 'premium-1', customerId: 'c10', startTime: DateTime(2026, 7, 6), serviceId: 'svc-2'),
    ];
    final summary = computeFinanceSummary(
      bookings: bookings,
      services: const [service, premium],
      costItems: const [],
      monthStart: monthStart,
      monthEnd: monthEnd,
      currencySymbol: '£',
    );

    expect(summary.recommendations, [
      '£250.00 above break-even this month.',
      'Most customers visit once a month — a half-price second cut this month could turn '
          'one-time visitors into repeat customers.',
      'Premium Styling is one of your highest-priced services but made up only 9% of bookings '
          'this month — a discount or feature spot could boost its uptake.',
    ]);
  });

  test('quietest day: an uneven weekday spread flags the slowest day', () {
    final monday = julyDateForWeekday(DateTime.monday);
    final tuesday = julyDateForWeekday(DateTime.tuesday);
    final wednesday = julyDateForWeekday(DateTime.wednesday);
    final thursday = julyDateForWeekday(DateTime.thursday);

    final summary = computeFinanceSummary(
      bookings: [
        completedBooking(id: 'b1', customerId: 'c1', startTime: monday),
        completedBooking(id: 'b2', customerId: 'c2', startTime: monday),
        completedBooking(id: 'b3', customerId: 'c1', startTime: monday),
        completedBooking(id: 'b4', customerId: 'c1', startTime: tuesday),
        completedBooking(id: 'b5', customerId: 'c2', startTime: wednesday),
        completedBooking(id: 'b6', customerId: 'c1', startTime: thursday),
      ],
      services: const [service],
      costItems: const [],
      monthStart: monthStart,
      monthEnd: monthEnd,
      currencySymbol: '£',
    );

    expect(summary.recommendations, [
      '£120.00 above break-even this month.',
      'Tuesday is your quietest day — an off-peak discount could help fill that time.',
    ]);
  });
}
