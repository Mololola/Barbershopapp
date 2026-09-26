import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/loading.dart';
import '../../business/domain/business.dart';
import '../application/admin_controller.dart';
import '../domain/admin_metrics.dart';

String _money(int cents, [String? currency]) =>
    '${currency == null ? '' : currencySymbol(currency)}${(cents / 100).toStringAsFixed(2)}';

/// "£120.00 · €80.00", or "—" when nothing's there yet.
String _perCurrency(List<CurrencyAmount> amounts) =>
    amounts.isEmpty ? '—' : amounts.map((a) => _money(a.amountCents, a.currency)).join(' · ');

int _countOf(List<CurrencyAmount> amounts) => amounts.fold(0, (sum, a) => sum + a.count);

String _percent(int part, int whole) => whole == 0 ? '—' : '${(part * 100 / whole).round()}%';

/// "+5 in 30 days (was 3)" — growth at a glance.
String _growth(WindowedCount count) =>
    '+${count.last30Days} in 30 days (previous 30: ${count.previous30Days}) · +${count.last7Days} in 7 days';

const _subscriptionStatusLabels = {
  'active': 'Active',
  'incomplete': 'Checkout started, never finished',
  'suspended': 'Payment failed — in grace period',
  'canceled': 'Cancelled',
  'never subscribed': 'Never started checkout',
};

/// The owner's at-a-glance numbers — see GET /admin/metrics. Pull down to
/// refresh; nothing here changes data.
class AdminOverviewTab extends ConsumerWidget {
  const AdminOverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(adminMetricsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminMetricsProvider.future),
      child: metrics.when(
        loading: () => const LoadingView(),
        error: (error, _) => ListView(
          children: [Padding(padding: const EdgeInsets.all(24), child: Text('Couldn\'t load: $error'))],
        ),
        data: (m) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Section(
              title: 'Revenue',
              note: 'What the app knows from Stripe. Stripe\'s own dashboard is the source of truth for money '
                  'actually received, fees and refunds.',
              stats: [
                _Stat('Monthly recurring revenue', _perCurrency(m.monthlyRecurring),
                    '${_countOf(m.monthlyRecurring)} paying businesses, billed every month'),
                _Stat('In trial', _perCurrency(m.monthlyRecurringInTrial),
                    '${_countOf(m.monthlyRecurringInTrial)} businesses — becomes revenue when their trial ends'),
                _Stat('At risk', _perCurrency(m.monthlyRecurringAtRisk),
                    '${_countOf(m.monthlyRecurringAtRisk)} businesses whose payment failed (grace period)'),
                _Stat('Finance tool unlocks', _perCurrency(m.financeToolPaid),
                    '${_countOf(m.financeToolPaid)} paid · ${m.financeToolTrialsActive} on a free trial now'),
                _Stat('3D design slots', _money(m.designSlotRevenueGbpCents, 'GBP'),
                    '${m.designSlotBundlesSold} bundles sold to customers'),
              ],
            ),
            _Section(
              title: 'Businesses',
              stats: [
                _Stat('Total businesses', '${m.businesses.total}', _growth(m.businesses)),
                _Stat('Live for customers', '${m.bookable}',
                    'Have a service and a staff member, and aren\'t suspended'),
                _Stat('Finished setup', '${m.setupComplete}', 'Completed the 3-step setup'),
                _Stat('Suspended', '${m.suspended}', 'Hidden from customers for non-payment'),
                _Stat('Trials running', '${m.trialsActive}', '${m.trialsEndingIn7Days} end in the next 7 days'),
                _Stat('Trial → paying', _percent(m.trialsConvertedToPaying, m.trialsEnded),
                    '${m.trialsConvertedToPaying} of ${m.trialsEnded} finished trials now pay'),
                if (m.grandfathered > 0) _Stat('Free (grandfathered)', '${m.grandfathered}', 'Never billed'),
              ],
              breakdown: _Breakdown(
                title: 'Subscription status',
                rows: [
                  for (final s in m.subscriptionsByStatus) (_subscriptionStatusLabels[s.name] ?? s.name, '${s.count}'),
                ],
              ),
            ),
            _Section(
              title: 'Users',
              stats: [
                _Stat('Customers', '${m.customers.total}', _growth(m.customers)),
                _Stat('Business accounts', '${m.businessAccounts.total}', _growth(m.businessAccounts)),
                _Stat('Barbers (worker profiles)', '${m.workersOptedIn}',
                    '${m.workersLookingForWork} looking for work'),
                _Stat('Under 18', '${m.minors}', 'Customer accounts with restricted features'),
                _Stat('Stuck signing up', '${m.awaitingEmailConfirmation + m.confirmedWithoutProfile}',
                    '${m.awaitingEmailConfirmation} haven\'t confirmed their email · '
                        '${m.confirmedWithoutProfile} confirmed but never finished'),
              ],
              breakdown: _Breakdown(
                title: 'Sign-in methods (an account can have both)',
                rows: [for (final s in m.signInMethods) (s.name, '${s.count}')],
              ),
            ),
            _Section(
              title: 'Bookings & reviews',
              stats: [
                _Stat('Bookings made', '${m.bookings.total}', _growth(m.bookings)),
                _Stat('Upcoming', '${m.upcomingBookings}', 'Confirmed and still in the future'),
                _Stat('Completed', '${m.completedBookings}', 'Marked done and paid by the shop'),
                _Stat('Cancelled', '${m.cancelledBookings}',
                    '${_percent(m.cancelledBookings, m.bookings.total)} of all bookings'),
                _Stat('Reviews', '${m.reviews.total}', _growth(m.reviews)),
                _Stat(
                  'Average ratings',
                  m.averageShopRating == null ? '—' : '${m.averageShopRating} ★',
                  m.averageShopRating == null
                      ? 'No reviews yet'
                      : 'Shop ${m.averageShopRating} · Barber ${m.averageWorkerRating} · '
                          'Haircut ${m.averageHaircutRating}',
                ),
              ],
              breakdown: _Breakdown(
                title: 'Last 6 months: new customers / new businesses / completed bookings',
                rows: [
                  for (final t in m.monthlyTrend)
                    (t.month, '${t.newCustomers} / ${t.newBusinesses} / ${t.completedBookings}'),
                ],
              ),
            ),
            _Section(
              title: 'Rewards',
              note: 'Customer review rewards. "Owed" is everything earned that hasn\'t been paid out yet.',
              stats: [
                _Stat('Earned', _money(m.rewardsEarnedCents),
                    '${_money(m.rewardsEarnedLast30DaysCents)} in the last 30 days'),
                _Stat('Paid out', _money(m.rewardsPaidOutCents), 'Payout requests marked paid'),
                _Stat('Owed', _money(m.rewardsOwedCents), 'Your outstanding liability to customers'),
                _Stat('Payout requests waiting', '${m.pendingPayouts}',
                    '${_money(m.pendingPayoutsCents)} — approve them in the Payouts tab'),
                _Stat('Quality reviewers', '${m.qualityReviewers}', 'Customers on the higher reward tier'),
              ],
              breakdown: _Breakdown(
                title: 'Worth reading: most thoughtful reviewers (last 60 days, not yet quality reviewers) — '
                    'flag them in the Customers tab',
                rows: [
                  for (final c in m.reviewerCandidates)
                    ('@${c.username}', '${c.reviewsWithComments} with comments / ${c.reviews} reviews'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value, this.detail);

  final String label;
  final String value;
  final String detail;
}

class _Breakdown {
  const _Breakdown({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.stats, this.note, this.breakdown});

  final String title;
  final String? note;
  final List<_Stat> stats;
  final _Breakdown? breakdown;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: textTheme.titleLarge),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(note!, style: textTheme.bodySmall),
          ],
          const SizedBox(height: 8),
          for (final stat in stats)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(stat.label),
                subtitle: Text(stat.detail),
                trailing: ConstrainedBox(
                  // Leaves room for the label on a phone even with two
                  // currencies side by side.
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(stat.value, style: textTheme.titleMedium, textAlign: TextAlign.end),
                ),
              ),
            ),
          if (breakdown != null && breakdown!.rows.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(breakdown!.title, style: textTheme.labelLarge),
            for (final (label, value) in breakdown!.rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(label)),
                    const SizedBox(width: 8),
                    Flexible(child: Text(value, textAlign: TextAlign.end)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
