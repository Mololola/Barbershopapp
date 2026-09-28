import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/application/admin_controller.dart';
import 'package:mobile/features/admin/domain/admin_metrics.dart';
import 'package:mobile/features/admin/presentation/admin_overview_tab.dart';

Map<String, dynamic> _windowed(int total, int last30) =>
    {'total': total, 'last_7_days': 1, 'last_30_days': last30, 'previous_30_days': 2};

/// Shaped exactly like GET /admin/metrics.
final _json = <String, dynamic>{
  'users': {
    'customers': _windowed(40, 12),
    'business_accounts': _windowed(9, 3),
    'minors': 2,
    'workers_opted_in': 5,
    'workers_looking_for_work': 3,
    'sign_in_methods': [
      {'name': 'email', 'count': 30},
      {'name': 'google', 'count': 15},
    ],
    'awaiting_email_confirmation': 1,
    'confirmed_without_profile': 2,
  },
  'businesses': {
    'businesses': _windowed(8, 3),
    'setup_complete': 7,
    'bookable': 6,
    'suspended': 1,
    'subscriptions_by_status': [
      {'name': 'active', 'count': 5},
      {'name': 'suspended', 'count': 1},
    ],
    'grandfathered': 0,
    'trials_active': 2,
    'trials_ending_in_7_days': 1,
    'trials_ended': 4,
    'trials_converted_to_paying': 3,
  },
  'revenue': {
    'monthly_recurring': [
      {'currency': 'EUR', 'amount_cents': 45000, 'count': 2},
      {'currency': 'GBP', 'amount_cents': 60000, 'count': 3},
    ],
    'monthly_recurring_in_trial': [
      {'currency': 'GBP', 'amount_cents': 15000, 'count': 1},
    ],
    'monthly_recurring_at_risk': [],
    'finance_tool_paid': [],
    'finance_tool_trials_active': 1,
    'design_slot_bundles_sold': 3,
    'design_slot_revenue_gbp_cents': 600,
  },
  'rewards': {
    'earned_cents': 4200,
    'earned_last_30_days_cents': 1200,
    'paid_out_cents': 2000,
    'pending_payouts': 1,
    'pending_payouts_cents': 2000,
    'owed_cents': 2200,
    'quality_reviewers': 1,
  },
  'activity': {
    'bookings': _windowed(120, 30),
    'upcoming_bookings': 10,
    'completed_bookings': 100,
    'cancelled_bookings': 10,
    'reviews': _windowed(80, 20),
    'average_shop_rating': 4.6,
    'average_worker_rating': 4.8,
    'average_haircut_rating': 4.5,
    'monthly_trend': [
      {'month': '2026-08', 'new_customers': 10, 'new_businesses': 2, 'completed_bookings': 40},
      {'month': '2026-09', 'new_customers': 12, 'new_businesses': 3, 'completed_bookings': 60},
    ],
  },
};

void main() {
  test('AdminMetrics parses the /admin/metrics response', () {
    final m = AdminMetrics.fromJson(_json);

    expect(m.customers.total, 40);
    expect(m.monthlyRecurring.map((a) => a.currency), ['EUR', 'GBP']);
    expect(m.averageWorkerRating, 4.8);
    expect(m.monthlyTrend.last.completedBookings, 60);
  });

  testWidgets('renders every section at phone width, revenue split by currency', (tester) async {
    tester.view.physicalSize = const Size(1080, 12000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminMetricsProvider.overrideWith((ref) async => AdminMetrics.fromJson(_json))],
        child: const MaterialApp(home: Scaffold(body: AdminOverviewTab())),
      ),
    );
    await tester.pumpAndSettle();

    for (final section in ['Revenue', 'Growth', 'Businesses', 'People', 'Bookings & reviews', 'Rewards']) {
      expect(find.text(section), findsOneWidget);
    }
    // Hero: paying MRR per currency, whole amounts without pence.
    expect(find.text('€450 · £600'), findsOneWidget);
    // Action items only for things that need doing.
    expect(find.text('Needs your attention'), findsOneWidget);
    expect(find.textContaining('1 payout request waiting'), findsOneWidget);
    expect(find.textContaining('1 business suspended'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget); // 3 of 4 finished trials converted
    // Customers: +12 in 30 days vs 2 the 30 before.
    expect(find.text('+12 in 30 days (+10)'), findsOneWidget);
  });

  testWidgets('shows "all clear" when nothing needs attention', (tester) async {
    final calm = Map<String, dynamic>.of(_json)
      ..['rewards'] = {...(_json['rewards'] as Map<String, dynamic>), 'pending_payouts': 0}
      ..['businesses'] = {...(_json['businesses'] as Map<String, dynamic>), 'suspended': 0, 'trials_ending_in_7_days': 0}
      ..['users'] = {
        ...(_json['users'] as Map<String, dynamic>),
        'awaiting_email_confirmation': 0,
        'confirmed_without_profile': 0,
      };
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adminMetricsProvider.overrideWith((ref) async => AdminMetrics.fromJson(calm))],
        child: const MaterialApp(home: Scaffold(body: AdminOverviewTab())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing needs you right now'), findsOneWidget);
  });
}
