import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/loading.dart';
import '../../../core/theme.dart';
import '../../business/domain/business.dart';
import '../application/admin_controller.dart';
import '../domain/admin_metrics.dart';

/// "Getting better" — paired with an up arrow, never colour alone. Worse
/// uses the app's rust.
const _improving = Color(0xFF2E7D4F);

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _grouped(int value) =>
    value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// £1,240 / £12.50 — whole amounts drop the pence to stay scannable.
String _money(int cents, [String? currency]) {
  final symbol = currency == null ? '' : currencySymbol(currency);
  return cents % 100 == 0 ? '$symbol${_grouped(cents ~/ 100)}' : '$symbol${(cents / 100).toStringAsFixed(2)}';
}

/// "£1,240 · €860", or "—" when there's nothing yet.
String _perCurrency(List<CurrencyAmount> amounts) =>
    amounts.isEmpty ? '—' : amounts.map((a) => _money(a.amountCents, a.currency)).join(' · ');

int _countOf(List<CurrencyAmount> amounts) => amounts.fold(0, (sum, a) => sum + a.count);

String _percent(int part, int whole) => whole == 0 ? '—' : '${(part * 100 / whole).round()}%';

const _subscriptionStatusLabels = {
  'active': 'Active',
  'incomplete': 'Checkout started, not finished',
  'suspended': 'Payment failed (grace period)',
  'canceled': 'Cancelled',
  'never subscribed': 'Never started checkout',
};

/// The owner's dashboard — see GET /admin/metrics. Read top to bottom:
/// what needs you now, the headline revenue, the four vital signs, then
/// detail by area. Pull down to refresh; nothing here changes data.
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _NeedsAttention(items: [
              if (m.pendingPayouts > 0)
                (Icons.payments_outlined, '${m.pendingPayouts} payout request${m.pendingPayouts == 1 ? '' : 's'} '
                    'waiting (${_money(m.pendingPayoutsCents)}) — Payouts tab'),
              if (m.trialsEndingIn7Days > 0)
                (Icons.hourglass_bottom, '${m.trialsEndingIn7Days} trial${m.trialsEndingIn7Days == 1 ? '' : 's'} '
                    'ending this week'),
              if (_countOf(m.monthlyRecurringAtRisk) > 0)
                (Icons.credit_card_off_outlined, '${_countOf(m.monthlyRecurringAtRisk)} failed payment'
                    '${_countOf(m.monthlyRecurringAtRisk) == 1 ? '' : 's'} (${_perCurrency(m.monthlyRecurringAtRisk)}/mo at risk)'),
              if (m.suspended > 0) (Icons.block, '${m.suspended} business${m.suspended == 1 ? '' : 'es'} hidden (unpaid)'),
              if (m.awaitingEmailConfirmation + m.confirmedWithoutProfile > 0)
                (Icons.person_off_outlined, '${m.awaitingEmailConfirmation + m.confirmedWithoutProfile} '
                    'sign-up${m.awaitingEmailConfirmation + m.confirmedWithoutProfile == 1 ? '' : 's'} not finished'),
            ]),
            const SizedBox(height: 16),
            _Hero(
              label: 'Monthly recurring revenue',
              value: _perCurrency(m.monthlyRecurring),
              caption: '${_countOf(m.monthlyRecurring)} paying businesses'
                  '${m.monthlyRecurringInTrial.isEmpty ? '' : ' · ${_perCurrency(m.monthlyRecurringInTrial)} more once trials end'}',
            ),
            const SizedBox(height: 12),
            _TileGrid(tiles: [
              _Tile('Live businesses', '${m.bookable}', caption: 'of ${m.businesses.total} total', delta: m.businesses),
              _Tile('Customers', _grouped(m.customers.total), delta: m.customers),
              _Tile('Bookings, 30 days', _grouped(m.bookings.last30Days),
                  caption: '${m.upcomingBookings} upcoming', delta: m.bookings, deltaIsRecentCount: true),
              _Tile('Average rating', m.averageShopRating == null ? '—' : '${m.averageShopRating} ★',
                  caption: '${m.reviews.total} reviews'),
            ]),
            const _SectionTitle('Revenue', note: 'From Stripe\'s updates. Stripe\'s dashboard has cash received, fees and refunds.'),
            _TileGrid(tiles: [
              _Tile('In trial', _perCurrency(m.monthlyRecurringInTrial),
                  caption: '${_countOf(m.monthlyRecurringInTrial)} businesses, billed after trial'),
              _Tile('At risk', _perCurrency(m.monthlyRecurringAtRisk), caption: 'Payment failed'),
              _Tile('Finance tool', _perCurrency(m.financeToolPaid),
                  caption: '${_countOf(m.financeToolPaid)} paid · ${m.financeToolTrialsActive} trialling'),
              _Tile('3D design slots', _money(m.designSlotRevenueGbpCents, 'GBP'),
                  caption: '${m.designSlotBundlesSold} bundles'),
            ]),
            const _SectionTitle('Growth', note: 'Last 6 months. Tap a bar for its exact number.'),
            _MonthBars(title: 'New customers', months: m.monthlyTrend, valueOf: (t) => t.newCustomers),
            _MonthBars(title: 'New businesses', months: m.monthlyTrend, valueOf: (t) => t.newBusinesses),
            _MonthBars(title: 'Completed bookings', months: m.monthlyTrend, valueOf: (t) => t.completedBookings),
            const _SectionTitle('Businesses'),
            _TileGrid(tiles: [
              _Tile('Finished setup', '${m.setupComplete}', caption: 'of ${m.businesses.total}'),
              _Tile('Trials running', '${m.trialsActive}', caption: '${m.trialsEndingIn7Days} end this week'),
              _Tile('Trial → paying', _percent(m.trialsConvertedToPaying, m.trialsEnded),
                  caption: '${m.trialsConvertedToPaying} of ${m.trialsEnded} finished trials'),
              _Tile('Hidden', '${m.suspended}', caption: 'Unpaid — not shown to customers'),
              if (m.grandfathered > 0) _Tile('Free (grandfathered)', '${m.grandfathered}', caption: 'Never billed'),
            ]),
            _Breakdown(
              title: 'Subscriptions',
              rows: [
                for (final s in m.subscriptionsByStatus) (_subscriptionStatusLabels[s.name] ?? s.name, s.count),
              ],
            ),
            const _SectionTitle('People'),
            _TileGrid(tiles: [
              _Tile('Business accounts', '${m.businessAccounts.total}', delta: m.businessAccounts),
              _Tile('Barbers', '${m.workersOptedIn}', caption: '${m.workersLookingForWork} looking for work'),
              _Tile('Under 18', '${m.minors}', caption: 'Restricted accounts'),
              _Tile('Unfinished sign-ups', '${m.awaitingEmailConfirmation + m.confirmedWithoutProfile}',
                  caption: '${m.awaitingEmailConfirmation} unconfirmed email'),
            ]),
            _Breakdown(title: 'Sign-in methods (an account can have both)', rows: [
              for (final s in m.signInMethods) (s.name == 'email' ? 'Email & password' : 'Google', s.count),
            ]),
            const _SectionTitle('Bookings & reviews'),
            _TileGrid(tiles: [
              _Tile('Completed', _grouped(m.completedBookings), caption: 'All time'),
              _Tile('Cancelled', _percent(m.cancelledBookings, m.bookings.total),
                  caption: '${m.cancelledBookings} of ${m.bookings.total} bookings'),
              _Tile('Barber rating', m.averageWorkerRating == null ? '—' : '${m.averageWorkerRating} ★'),
              _Tile('Haircut rating', m.averageHaircutRating == null ? '—' : '${m.averageHaircutRating} ★'),
              _Tile('Reviews', _grouped(m.reviews.total), delta: m.reviews),
            ]),
            const _SectionTitle('Rewards', note: 'Review rewards customers earn and can withdraw.'),
            _TileGrid(tiles: [
              _Tile('Owed to customers', _money(m.rewardsOwedCents), caption: 'Earned, not yet paid'),
              _Tile('Paid out', _money(m.rewardsPaidOutCents)),
              _Tile('Earned, 30 days', _money(m.rewardsEarnedLast30DaysCents),
                  caption: '${_money(m.rewardsEarnedCents)} all time'),
              _Tile('Quality reviewers', '${m.qualityReviewers}', caption: 'Suggestions: Customers tab'),
            ]),
          ],
        ),
      ),
    );
  }
}

class _NeedsAttention extends StatelessWidget {
  const _NeedsAttention({required this.items});

  final List<(IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final allClear = items.isEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (allClear ? _improving : AppColors.rust).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (allClear ? _improving : AppColors.rust).withValues(alpha: 0.35)),
      ),
      child: allClear
          ? Row(
              children: [
                const Icon(Icons.check_circle_outline, color: _improving, size: 20),
                const SizedBox(width: 10),
                Text('Nothing needs you right now', style: textTheme.bodyMedium),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Needs your attention', style: textTheme.titleSmall),
                for (final (icon, text) in items)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: AppColors.rust, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(text, style: textTheme.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.label, required this.value, required this.caption});

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: textTheme.labelLarge?.copyWith(color: AppColors.steel)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            Text(caption, style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Tile {
  const _Tile(this.label, this.value, {this.caption, this.delta, this.deltaIsRecentCount = false});

  final String label;
  final String value;
  final String? caption;

  /// Shows "▲ n vs previous 30 days": new in the last 30 days compared with
  /// the 30 before. Always "more is better" for the tiles that use it.
  final WindowedCount? delta;

  /// The tile's value already is the last-30-days count, so the delta
  /// compares that directly rather than labelling it "new".
  final bool deltaIsRecentCount;
}

class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});

  final List<_Tile> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final tile in tiles) SizedBox(width: width, child: _TileCard(tile: tile))],
        );
      },
    );
  }
}

class _TileCard extends StatelessWidget {
  const _TileCard({required this.tile});

  final _Tile tile;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final delta = tile.delta;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tile.label, style: textTheme.labelMedium?.copyWith(color: AppColors.steel)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(tile.value, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
            ),
            if (delta != null) _DeltaLine(count: delta, isRecentCount: tile.deltaIsRecentCount),
            if (tile.caption != null) Text(tile.caption!, style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _DeltaLine extends StatelessWidget {
  const _DeltaLine({required this.count, required this.isRecentCount});

  final WindowedCount count;
  final bool isRecentCount;

  @override
  Widget build(BuildContext context) {
    final change = count.last30Days - count.previous30Days;
    final (icon, color) = change > 0
        ? (Icons.arrow_upward, _improving)
        : change < 0
            ? (Icons.arrow_downward, AppColors.rust)
            : (Icons.arrow_forward, AppColors.steel);
    final text = isRecentCount
        ? '${change >= 0 ? '+' : ''}$change vs previous 30 days'
        : '+${count.last30Days} in 30 days (${change >= 0 ? '+' : ''}$change)';
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Flexible(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color))),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.note});

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleLarge),
          if (note != null) Text(note!, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Status rows as label + count with a proportional bar, so the biggest
/// group is visible at a glance — one hue, since the bars are magnitudes.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.title, required this.rows});

  final String title;
  final List<(String, int)> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    final max = rows.map((r) => r.$2).fold(1, (a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: textTheme.labelLarge),
          for (final (label, count) in rows)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(label, style: textTheme.bodyMedium)),
                      Text('$count', style: textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: count / max,
                      minHeight: 6,
                      color: AppColors.brass,
                      backgroundColor: AppColors.brass.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One measure over the last 6 months as columns — a single series on one
/// axis, current month labelled with its value, any month's exact number
/// on tap.
class _MonthBars extends StatelessWidget {
  const _MonthBars({required this.title, required this.months, required this.valueOf});

  final String title;
  final List<MonthTrend> months;
  final int Function(MonthTrend) valueOf;

  static const _plotHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final values = [for (final m in months) valueOf(m)];
    final max = values.fold(0, (a, b) => a > b ? a : b);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: textTheme.labelLarge)),
              Text('${values.fold(0, (a, b) => a + b)} in 6 months', style: textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < months.length; i++)
                Expanded(
                  child: Tooltip(
                    triggerMode: TooltipTriggerMode.tap,
                    message: '${_monthLabel(months[i].month, withYear: true)}: ${values[i]}',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Only the latest month carries its number; the
                          // rest are a tap away.
                          Text(i == months.length - 1 ? '${values[i]}' : '', style: textTheme.labelSmall),
                          const SizedBox(height: 2),
                          Container(
                            height: max == 0 ? 2 : 2 + (_plotHeight - 2) * values[i] / max,
                            decoration: BoxDecoration(
                              color: values[i] == 0 ? AppColors.divider : AppColors.brass,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(_monthLabel(months[i].month), style: textTheme.labelSmall),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "2026-09" -> "Sep" (or "Sep 2026").
String _monthLabel(String yearMonth, {bool withYear = false}) {
  final [year, month] = yearMonth.split('-');
  final name = _monthNames[int.parse(month) - 1];
  return withYear ? '$name $year' : name;
}
