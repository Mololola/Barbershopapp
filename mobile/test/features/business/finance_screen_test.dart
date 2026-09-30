import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/business/application/business_controller.dart';
import 'package:mobile/features/business/domain/business.dart';
import 'package:mobile/features/business/domain/finance_overview.dart';
import 'package:mobile/features/business/presentation/finance_screen.dart';

Map<String, dynamic> _month(String month, {int revenue = 9000, int costs = 60000}) => {
      'month': month,
      'booking_revenue_cents': revenue,
      'other_income_cents': 0,
      'revenue_cents': revenue,
      'costs_cents': costs,
      'net_cents': revenue - costs,
      'completed_bookings': revenue ~/ 1500,
    };

/// Shaped like GET /businesses/{id}/finance.
Map<String, dynamic> _overview({required bool premium, bool trialUsed = false}) {
  final now = DateTime.now();
  final month = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
  return {
    'currency': 'GBP',
    'month': month,
    'is_current_month': true,
    'premium_state': {'has_premium': premium, 'trial_ends_at': null, 'trial_used': trialUsed, 'subscribed': premium},
    'summary': {
      ..._month(month, revenue: 9500, costs: 85000),
      'other_income_cents': 8000,
      'booking_revenue_cents': 1500,
      'completed_bookings': 1,
      'net_cents': -75500,
      'average_ticket_cents': 1500,
      'bookings_to_break_even': 51,
    },
    'premium': !premium
        ? null
        : {
            'forecast': {
              'projected_revenue_cents': 125000,
              'projected_net_cents': 40000,
              'confirmed_upcoming_cents': 3000,
              'break_even_day': '${month.substring(0, 8)}19',
              'already_broken_even': false,
            },
            'history': [for (var i = 11; i >= 0; i--) _month(month)],
            'utilisation': 0.42,
            'heatmap': [
              {'weekday': 0, 'hour': 9, 'utilisation': 0.9},
              {'weekday': 0, 'hour': 10, 'utilisation': 0.1},
            ],
            'barbers': [
              {'name': 'Luis', 'bookings': 6, 'revenue_cents': 9000, 'utilisation': 0.25, 'average_rating': 4.7},
            ],
            'services': [
              {'name': 'Skin fade', 'bookings': 6, 'revenue_cents': 9000, 'share': 1.0, 'previous_bookings': 2},
            ],
            'customers': {
              'customers_last_30_days': 3,
              'new_last_30_days': 2,
              'returning_last_30_days': 1,
              'return_rate': 0.5,
              'at_risk': [
                {'username': 'rob', 'visits': 4, 'last_visit': '2026-07-01', 'usual_gap_days': 28, 'days_since': 80},
              ],
            },
            'suggestions': [
              {
                'kind': 'second_visit_bundle',
                'title': "Sell '2 cuts for the price of 1.5' this month",
                'detail': '12 of your 14 customers came once.',
                'monthly_gain_cents': 2400,
                'assumptions': 'Assumes 1 in 5 buys it.',
              },
            ],
            'average_ticket_cents': 1500,
            'average_duration_minutes': 45.0,
          },
  };
}

void main() {
  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month);
  final rent = CostItem(
    id: 'c1',
    businessId: 'b',
    label: 'Rent',
    amountCents: 60000,
    kind: CostKind.monthly,
    startsOn: DateTime(now.year, now.month - 2),
  );

  Widget buildTestable(Map<String, dynamic> json) {
    return ProviderScope(
      overrides: [
        financeOverviewProvider(thisMonth).overrideWith((ref) async => FinanceOverview.fromJson(json)),
        costItemsProvider.overrideWith((ref) async => [rent]),
      ],
      child: const MaterialApp(home: FinanceScreen()),
    );
  }

  Future<void> pumpPhone(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(1080, 12000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  testWidgets('free: the month\'s result, costs and other income, plus the way into premium', (tester) async {
    await pumpPhone(tester, buildTestable(_overview(premium: false)));

    expect(find.text('Loss'), findsOneWidget);
    expect(find.text('-£755'), findsOneWidget);
    expect(find.textContaining('51 more bookings at your average £15'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('£80'), findsWidgets); // other income
    expect(find.text('Try it free for 14 days'), findsOneWidget);
    expect(find.text('Premium insights'), findsNothing);
  });

  testWidgets('after the trial, the upgrade is the monthly subscription in the shop\'s currency', (tester) async {
    await pumpPhone(tester, buildTestable(_overview(premium: false, trialUsed: true)));

    expect(find.text('Get Premium — £9.99/month'), findsOneWidget);
  });

  testWidgets('premium: forecast, priced suggestions, charts, barbers, customers and what-if', (tester) async {
    await pumpPhone(tester, buildTestable(_overview(premium: true)));

    expect(find.text('Premium insights'), findsOneWidget);
    expect(find.text('Month-end forecast'), findsOneWidget);
    expect(find.textContaining('break even on 19'), findsOneWidget);
    expect(find.text("Sell '2 cuts for the price of 1.5' this month"), findsOneWidget);
    expect(find.text('+£24/mo'), findsOneWidget);
    expect(find.text('Profit, last 12 months'), findsOneWidget);
    expect(find.text('When your chairs are busy'), findsOneWidget);
    expect(find.text('Luis'), findsOneWidget);
    expect(find.text('@rob'), findsOneWidget);
    expect(find.text('What if…'), findsOneWidget);
    expect(find.text('Try it free for 14 days'), findsNothing);
  });

  group('domain', () {
    test('formatMoney drops pence on whole amounts and signs losses', () {
      expect(formatMoney(124000, 'GBP'), '£1,240');
      expect(formatMoney(1250, 'EUR'), '€12.50');
      expect(formatMoney(-8500, 'GBP'), '-£85');
    });

    test('simulateNet scales booking revenue only', () {
      // £1,000 of bookings, +10% prices, -5% bookings = £1,045; + £200 other - £900 costs.
      expect(
        simulateNet(
          bookingRevenueCents: 100000,
          otherIncomeCents: 20000,
          costsCents: 90000,
          priceChange: 0.10,
          bookingChange: -0.05,
        ),
        34500,
      );
    });

    test('a monthly cost applies from its start until it ends; a one-off to its month', () {
      final stopped = CostItem(
        businessId: 'b',
        label: 'Old software',
        amountCents: 1,
        kind: CostKind.monthly,
        startsOn: DateTime(2026, 6),
        endsOn: DateTime(2026, 8),
      );
      expect(stopped.appliesTo(DateTime(2026, 5)), isFalse);
      expect(stopped.appliesTo(DateTime(2026, 8)), isTrue);
      expect(stopped.appliesTo(DateTime(2026, 9)), isFalse);
      final chair = CostItem(businessId: 'b', label: 'Chair', amountCents: 1, kind: CostKind.oneOff, startsOn: DateTime(2026, 9));
      expect(chair.appliesTo(DateTime(2026, 9)), isTrue);
      expect(chair.appliesTo(DateTime(2026, 10)), isFalse);
    });

    test('parses the premium response', () {
      final overview = FinanceOverview.fromJson(_overview(premium: true));
      expect(overview.premium!.history, hasLength(12));
      expect(overview.premium!.forecast!.breakEvenDay!.day, 19);
      expect(overview.premium!.customers.atRisk.single.username, 'rob');
    });
  });
}
