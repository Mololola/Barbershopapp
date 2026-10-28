import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/responsive.dart';
import '../../../core/theme.dart';
import '../application/business_controller.dart';
import '../domain/business.dart';
import '../domain/finance_overview.dart';
import 'finance_screen.dart';
import 'pay_on_website.dart';

const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _percent(double? share) => share == null ? '—' : '${(share * 100).round()}%';

/// Everything Premium adds below the free summary.
class PremiumSection extends StatelessWidget {
  const PremiumSection({super.key, required this.overview});

  final FinanceOverview overview;

  @override
  Widget build(BuildContext context) {
    final premium = overview.premium!;
    final currency = overview.currency;
    // The simulator starts from the last complete month — the current one
    // is only part-way through.
    final baseline = overview.isCurrentMonth && premium.history.length >= 2
        ? premium.history[premium.history.length - 2]
        : premium.history.last;

    final header = Row(
      children: [
        const Icon(Icons.workspace_premium, color: AppColors.brass),
        const SizedBox(width: 6),
        Expanded(child: Text('Premium insights', style: Theme.of(context).textTheme.titleLarge)),
      ],
    );
    final suggestions = [
      const _Heading('What to do next', 'Moves worked out from your own bookings, best first.'),
      if (premium.suggestions.isEmpty)
        const _Empty('Suggestions appear once you have about 10 completed bookings in the last 90 days.')
      else
        for (final s in premium.suggestions) _SuggestionCard(suggestion: s, currency: currency),
    ];
    final profit = [
      const _Heading('Profit, last 12 months', 'Tap a bar for the month\'s figures.'),
      _ProfitChart(months: premium.history, currency: currency),
    ];
    final busy = [
      _Heading(
        'When your chairs are busy',
        'Share of chair time booked, last 8 weeks · overall ${_percent(premium.utilisation)}',
      ),
      _Heatmap(cells: premium.heatmap),
    ];
    final barbers = [const _Heading('Barbers', 'Last 30 days'), _BarbersCard(barbers: premium.barbers, currency: currency)];
    final customers = [const _Heading('Customers', 'Last 30 days'), _CustomersCard(customers: premium.customers)];
    final services = [
      const _Heading('Services', 'Last 90 days, vs the 90 before'),
      _ServicesCard(services: premium.services, currency: currency),
    ];
    final whatIf = [
      _Heading('What if…', 'Try a change on ${monthLabel(baseline.month)}\'s figures before making it.'),
      _WhatIfCard(baseline: baseline, currency: currency),
    ];

    if (!isWideLayout(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          if (overview.premiumState.onTrial) _TrialBanner(state: overview.premiumState, currency: currency),
          if (premium.forecast != null) _ForecastCard(forecast: premium.forecast!, currency: currency),
          ...suggestions,
          ...profit,
          ...busy,
          ...barbers,
          ...customers,
          ...services,
          ...whatIf,
        ],
      );
    }

    // On a desktop, related panels sit side by side, each pair under the
    // same line so their headings align.
    Widget pair(List<Widget> left, List<Widget> right) => ResponsiveColumns(
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (overview.premiumState.onTrial) _TrialBanner(state: overview.premiumState, currency: currency),
        pair(
          [
            const _Heading('This month', 'Where you\'re heading at this pace'),
            if (premium.forecast != null)
              _ForecastCard(forecast: premium.forecast!, currency: currency, margin: EdgeInsets.zero)
            else
              const _Empty('A forecast appears once the month is under way.'),
          ],
          suggestions,
        ),
        pair(profit, busy),
        pair(barbers, customers),
        pair(services, whatIf),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(title, style: textTheme.titleMedium), Text(subtitle, style: textTheme.bodySmall)],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(text, style: const TextStyle(color: AppColors.steel)));
}

class _TrialBanner extends ConsumerWidget {
  const _TrialBanner({required this.state, required this.currency});

  final PremiumState state;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysLeft = state.trialEndsAt!.difference(DateTime.now()).inDays + 1;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      color: AppColors.brass.withValues(alpha: 0.12),
      child: ListTile(
        leading: const Icon(Icons.hourglass_bottom, color: AppColors.brass),
        title: Text('Free trial · $daysLeft day${daysLeft == 1 ? '' : 's'} left'),
        subtitle: canPayInThisApp
            ? Text('Keep Premium for ${currencySymbol(currency)}9.99/month')
            : const PayOnWebsiteNote(),
        trailing: !canPayInThisApp ? null : TextButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              final url = await ref.read(billingActionControllerProvider.notifier).startFinanceCheckout();
              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            } catch (error) {
              messenger.showSnackBar(SnackBar(content: Text(error.toString())));
            }
          },
          child: const Text('Subscribe'),
        ),
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast, required this.currency, this.margin = const EdgeInsets.only(top: 12)});

  final Forecast forecast;
  final String currency;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final positive = forecast.projectedNetCents >= 0;
    final day = forecast.breakEvenDay;
    final breakEven = forecast.alreadyBrokenEven
        ? 'You\'ve already covered this month\'s costs.'
        : day != null
            ? 'At this pace you\'ll break even on ${day.day} ${monthLabel(day, short: true)}.'
            : 'At this pace you won\'t cover this month\'s costs — see the suggestions below.';
    return Card(
      margin: margin,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Month-end forecast', style: textTheme.labelLarge?.copyWith(color: AppColors.steel)),
            Text(
              formatMoney(forecast.projectedNetCents, currency),
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: positive ? financeGain : AppColors.rust,
              ),
            ),
            Text('Projected ${positive ? 'profit' : 'loss'} on '
                '${formatMoney(forecast.projectedRevenueCents, currency)} revenue'),
            const SizedBox(height: 8),
            Text(breakEven, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (forecast.confirmedUpcomingCents > 0)
              Text('${formatMoney(forecast.confirmedUpcomingCents, currency)} already booked for the rest of the month.',
                  style: textTheme.bodySmall),
            Text('Based on your pace so far this month and bookings already in the diary.', style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, required this.currency});

  final Suggestion suggestion;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(suggestion.title, style: textTheme.titleSmall)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: financeGain.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+${formatMoney(suggestion.monthlyGainCents, currency)}/mo',
                    style: const TextStyle(color: financeGain, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(suggestion.detail),
            const SizedBox(height: 6),
            Text('Estimate: ${suggestion.assumptions}', style: textTheme.bodySmall?.copyWith(color: AppColors.steel)),
          ],
        ),
      ),
    );
  }
}

/// Profit by month as columns either side of a zero line — one measure,
/// one axis. Profit up in green, loss down in rust, and each month's exact
/// figures on tap.
class _ProfitChart extends StatelessWidget {
  const _ProfitChart({required this.months, required this.currency});

  final List<FinanceMonth> months;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final largest = months.fold<int>(1, (m, x) => x.netCents.abs() > m ? x.netCents.abs() : m);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Taller bars and "Jan" rather than "J" when there's room for them.
            final roomy = constraints.maxWidth / months.length >= 36;
            final half = roomy ? 100.0 : 70.0;
            return Row(
              children: [
                for (final month in months)
                  Expanded(
                    child: Tooltip(
                      triggerMode: TooltipTriggerMode.tap,
                      message: '${monthLabel(month.month)}\n'
                          'Revenue ${formatMoney(month.revenueCents, currency)}\n'
                          'Costs ${formatMoney(month.costsCents, currency)}\n'
                          '${month.netCents >= 0 ? 'Profit' : 'Loss'} ${formatMoney(month.netCents, currency)}',
                      child: Column(
                        children: [
                          SizedBox(
                            height: half,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: month.netCents > 0
                                  ? _bar(month.netCents / largest, financeGain, half: half, up: true)
                                  : null,
                            ),
                          ),
                          Container(height: 1, color: AppColors.steel),
                          SizedBox(
                            height: half,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: month.netCents < 0
                                  ? _bar(-month.netCents / largest, AppColors.rust, half: half, up: false)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            roomy ? monthLabel(month.month, short: true) : monthLabel(month.month, short: true)[0],
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _bar(double fraction, Color color, {required double half, required bool up}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      height: (half * fraction).clamp(2, half),
      decoration: BoxDecoration(
        color: color,
        borderRadius: up
            ? const BorderRadius.vertical(top: Radius.circular(4))
            : const BorderRadius.vertical(bottom: Radius.circular(4)),
      ),
    );
  }
}

/// Weekday × hour, darker = busier (one hue, light to dark). Closed hours
/// are left blank rather than shown as "empty".
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.cells});

  final List<HeatCell> cells;

  @override
  Widget build(BuildContext context) {
    if (cells.isEmpty) return const _Empty('Set your opening hours and staff to see this.');
    final byKey = {for (final c in cells) (c.weekday, c.hour): c};
    final days = {for (final c in cells) c.weekday}.toList()..sort();
    final firstHour = cells.map((c) => c.hour).reduce((a, b) => a < b ? a : b);
    final lastHour = cells.map((c) => c.hour).reduce((a, b) => a > b ? a : b);
    final hours = [for (var h = firstHour; h <= lastHour; h++) h];
    final small = Theme.of(context).textTheme.labelSmall;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 34),
                for (final h in hours)
                  Expanded(child: Text(h % 2 == 0 ? '$h' : '', textAlign: TextAlign.center, style: small)),
              ],
            ),
            for (final day in days)
              Row(
                children: [
                  SizedBox(width: 34, child: Text(_weekdayShort[day], style: small)),
                  for (final h in hours)
                    Expanded(
                      child: Builder(builder: (context) {
                        final cell = byKey[(day, h)];
                        final value = cell?.utilisation;
                        return Tooltip(
                          triggerMode: TooltipTriggerMode.tap,
                          message: value == null
                              ? '${_weekdayShort[day]} $h:00 · closed'
                              : '${_weekdayShort[day]} $h:00 · ${_percent(value)} booked',
                          child: Container(
                            height: 22,
                            margin: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: value == null
                                  ? Colors.transparent
                                  : AppColors.brass.withValues(alpha: 0.08 + 0.92 * value.clamp(0.0, 1.0)),
                              borderRadius: BorderRadius.circular(3),
                              border: value == null ? null : Border.all(color: AppColors.divider),
                            ),
                          ),
                        );
                      }),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Empty ', style: small),
                for (final v in [0.0, 0.25, 0.5, 0.75, 1.0])
                  Container(
                    width: 14,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    color: AppColors.brass.withValues(alpha: 0.08 + 0.92 * v),
                  ),
                Text(' Full', style: small),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BarbersCard extends StatelessWidget {
  const _BarbersCard({required this.barbers, required this.currency});

  final List<BarberStats> barbers;
  final String currency;

  @override
  Widget build(BuildContext context) {
    if (barbers.isEmpty) return const _Empty('No staff yet.');
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final b in barbers)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                      if (b.averageRating != null) Text('${b.averageRating} ★  '),
                      Text(formatMoney(b.revenueCents, currency)),
                    ],
                  ),
                  Text('${b.bookings} booking${b.bookings == 1 ? '' : 's'} · ${_percent(b.utilisation)} of their hours booked',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (b.utilisation ?? 0).clamp(0.0, 1.0),
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

class _CustomersCard extends StatelessWidget {
  const _CustomersCard({required this.customers});

  final CustomerStats customers;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              Text(label, textAlign: TextAlign.center, style: textTheme.bodySmall),
            ],
          ),
        );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                stat('${customers.customersLast30Days}', 'customers'),
                stat('${customers.newLast30Days}', 'new'),
                stat('${customers.returningLast30Days}', 'returning'),
                stat(_percent(customers.returnRate), 'came back*'),
              ],
            ),
            const SizedBox(height: 6),
            Text('* Of customers who visited 6–12 weeks ago, the share who have been back since.',
                style: textTheme.bodySmall),
            if (customers.atRisk.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Regulars you\'re losing', style: textTheme.titleSmall),
              Text('Usually back every few weeks — now well overdue. Worth a message.', style: textTheme.bodySmall),
              for (final c in customers.atRisk)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('@${c.username}'),
                  subtitle: Text('${c.visits} visits · usually every ${c.usualGapDays} days'),
                  trailing: Text('${c.daysSince} days ago', style: const TextStyle(color: AppColors.rust)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServicesCard extends StatelessWidget {
  const _ServicesCard({required this.services, required this.currency});

  final List<ServiceStats> services;
  final String currency;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) return const _Empty('No completed bookings in the last 90 days.');
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final s in services)
            ListTile(
              title: Text(s.name),
              subtitle: Text('${s.bookings} bookings · ${_percent(s.share)} of all · '
                  '${s.bookings >= s.previousBookings ? '▲' : '▼'} from ${s.previousBookings}'),
              trailing: Text(formatMoney(s.revenueCents, currency), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

class _WhatIfCard extends StatefulWidget {
  const _WhatIfCard({required this.baseline, required this.currency});

  final FinanceMonth baseline;
  final String currency;

  @override
  State<_WhatIfCard> createState() => _WhatIfCardState();
}

class _WhatIfCardState extends State<_WhatIfCard> {
  double _price = 0;
  double _bookings = 0;

  @override
  Widget build(BuildContext context) {
    final b = widget.baseline;
    final projected = simulateNet(
      bookingRevenueCents: b.bookingRevenueCents,
      otherIncomeCents: b.otherIncomeCents,
      costsCents: b.costsCents,
      priceChange: _price,
      bookingChange: _bookings,
    );
    final change = projected - b.netCents;
    String pct(double v) => '${v >= 0 ? '+' : ''}${(v * 100).round()}%';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Prices ${pct(_price)}'),
            Slider(value: _price, min: -0.2, max: 0.3, divisions: 10, label: pct(_price), onChanged: (v) => setState(() => _price = v)),
            Text('Number of bookings ${pct(_bookings)}'),
            Slider(
              value: _bookings,
              min: -0.3,
              max: 0.3,
              divisions: 12,
              label: pct(_bookings),
              onChanged: (v) => setState(() => _bookings = v),
            ),
            Row(
              children: [
                Expanded(child: Text('${monthLabel(b.month, short: true)} actual: ${formatMoney(b.netCents, widget.currency)}')),
                Text(
                  'Would be ${formatMoney(projected, widget.currency)}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: projected >= 0 ? financeGain : AppColors.rust),
                ),
              ],
            ),
            Text(
              '${change >= 0 ? '+' : ''}${formatMoney(change, widget.currency)} a month',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
