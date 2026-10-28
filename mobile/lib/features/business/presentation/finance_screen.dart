import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/loading.dart';
import '../../../core/responsive.dart';
import '../../../core/theme.dart';
import '../application/business_controller.dart';
import '../domain/business.dart';
import '../domain/finance_overview.dart';
import 'finance_premium.dart';
import 'pay_on_website.dart';

/// Profit green — always paired with a sign or arrow, never colour alone.
const financeGain = Color(0xFF2E7D4F);

/// The finance tool. The monthly summary, costs and other income are free
/// for every business; the analysis below them is Premium (enforced by the
/// backend, which only sends it to Premium shops).
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(financeOverviewProvider(_month));
    final wide = isWideLayout(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance'),
        actions: [
          // Pull-to-refresh needs a touch screen.
          if (wide)
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(financeOverviewProvider(_month)),
            ),
        ],
      ),
      body: overview.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text('Couldn\'t load your figures: $error')),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(financeOverviewProvider(_month).future),
          child: ListView(
            padding: wide ? const EdgeInsets.fromLTRB(24, 8, 24, 40) : const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                // Arrows either side of the month, not at the far edges of a wide page.
                child: SizedBox(
                  width: wide ? 360 : double.infinity,
                  child: _MonthSwitcher(
                    month: _month,
                    canGoForward: !data.isCurrentMonth,
                    onChanged: (month) => setState(() => _month = month),
                  ),
                ),
              ),
              ResponsiveColumns(
                flex: const [3, 2],
                spacing: 12,
                children: [
                  _ResultCard(overview: data),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CostsCard(month: _month, currency: data.currency),
                      const SizedBox(height: 12),
                      _OtherIncomeCard(month: _month, summary: data.summary, currency: data.currency),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (data.premium != null)
                PremiumSection(overview: data)
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: _UpgradeCard(state: data.premiumState, currency: data.currency),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({required this.month, required this.canGoForward, required this.onChanged});

  final DateTime month;
  final bool canGoForward;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous month',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
        ),
        Expanded(
          child: Text(monthLabel(month), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton(
          tooltip: 'Next month',
          icon: const Icon(Icons.chevron_right),
          onPressed: canGoForward ? () => onChanged(DateTime(month.year, month.month + 1)) : null,
        ),
      ],
    );
  }
}

/// The month in one glance: profit or loss, what made it, and the way to
/// break even when short.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.overview});

  final FinanceOverview overview;

  @override
  Widget build(BuildContext context) {
    final s = overview.summary;
    final currency = overview.currency;
    final textTheme = Theme.of(context).textTheme;
    final inProfit = s.netCents >= 0;
    final progress = s.costsCents == 0 ? 1.0 : (s.revenueCents / s.costsCents).clamp(0.0, 1.0);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(inProfit ? 'Profit' : 'Loss', style: textTheme.labelLarge?.copyWith(color: AppColors.steel)),
            Row(
              children: [
                Icon(inProfit ? Icons.trending_up : Icons.trending_down,
                    color: inProfit ? financeGain : AppColors.rust, size: 30),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatMoney(s.netCents, currency),
                      style: textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: inProfit ? financeGain : AppColors.rust,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Line('Bookings (${s.completedBookings} completed)', formatMoney(s.bookingRevenueCents, currency)),
            if (s.otherIncomeCents > 0) _Line('Other income', formatMoney(s.otherIncomeCents, currency)),
            _Line('Costs', formatMoney(-s.costsCents, currency)),
            const SizedBox(height: 14),
            Text(
              s.costsCents == 0
                  ? 'Add your costs below to see where you stand.'
                  : inProfit
                      ? 'Costs covered — everything from here is profit.'
                      : '${(progress * 100).round()}% of the way to breaking even',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: inProfit ? financeGain : AppColors.brass,
                backgroundColor: AppColors.divider,
              ),
            ),
            if (s.bookingsToBreakEven != null && s.costsCents > 0) ...[
              const SizedBox(height: 12),
              Text(
                '${s.bookingsToBreakEven} more booking${s.bookingsToBreakEven == 1 ? '' : 's'} at your average '
                '${formatMoney(s.averageTicketCents, currency)} would cover this month\'s costs.',
                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [Expanded(child: Text(label)), Text(value)]),
    );
  }
}

class _CostsCard extends ConsumerWidget {
  const _CostsCard({required this.month, required this.currency});

  final DateTime month;
  final String currency;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    final label = TextEditingController();
    final amount = TextEditingController();
    var kind = CostKind.monthly;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add a cost'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<CostKind>(
                  segments: const [
                    ButtonSegment(value: CostKind.monthly, label: Text('Every month')),
                    ButtonSegment(value: CostKind.oneOff, label: Text('One-off')),
                  ],
                  selected: {kind},
                  onSelectionChanged: (s) => setState(() => kind = s.first),
                ),
                const SizedBox(height: 8),
                Text(
                  kind == CostKind.monthly
                      ? 'Rent, wages, software… counted from ${monthLabel(month)} on.'
                      : 'Counted in ${monthLabel(month)} only.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextFormField(
                  controller: label,
                  decoration: const InputDecoration(labelText: 'What is it?'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: amount,
                  decoration: InputDecoration(labelText: 'Amount', prefixText: currencySymbol(currency)),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => double.tryParse(v ?? '') == null ? 'Enter an amount' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(context, true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await ref.read(financeControllerProvider.notifier).addCost(
          label: label.text.trim(),
          amountCents: (double.parse(amount.text) * 100).round(),
          kind: kind,
          month: month,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final costs = ref.watch(costItemsProvider).value ?? const <CostItem>[];
    final thisMonth = costs.where((c) => c.appliesTo(month)).toList();
    final controller = ref.read(financeControllerProvider.notifier);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Costs in ${monthLabel(month)}', style: Theme.of(context).textTheme.titleMedium)),
                TextButton.icon(onPressed: () => _add(context, ref), icon: const Icon(Icons.add), label: const Text('Add')),
              ],
            ),
            if (thisMonth.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No costs yet. Add rent, wages and anything else you pay to run the shop.'),
              ),
            for (final cost in thisMonth)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(cost.label),
                subtitle: Text(
                  cost.isAutomatic
                      ? 'Every month · added automatically'
                      : cost.kind == CostKind.oneOff
                          ? 'One-off'
                          : 'Every month',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatMoney(cost.amountCents, currency)),
                    if (cost.isAutomatic)
                      const SizedBox(width: 48)
                    else
                      PopupMenuButton<String>(
                        onSelected: (action) => action == 'stop'
                            ? controller.stopCostAfter(cost.id!, month)
                            : controller.deleteCost(cost.id!),
                        itemBuilder: (_) => [
                          if (cost.kind == CostKind.monthly)
                            PopupMenuItem(value: 'stop', child: Text('Stop after ${monthLabel(month)}')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(cost.kind == CostKind.monthly ? 'Delete from every month' : 'Delete'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OtherIncomeCard extends ConsumerWidget {
  const _OtherIncomeCard({required this.month, required this.summary, required this.currency});

  final DateTime month;
  final FinanceSummary summary;
  final String currency;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final amount = TextEditingController(
      text: summary.otherIncomeCents == 0 ? '' : (summary.otherIncomeCents / 100).toStringAsFixed(2),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Other income, ${monthLabel(month)}'),
        content: TextField(
          controller: amount,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Walk-ins, cash, product sales…',
            prefixText: currencySymbol(currency),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, double.tryParse(amount.text.isEmpty ? '0' : amount.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null) return;
    await ref.read(financeControllerProvider.notifier).setOtherIncome(month, (value * 100).round());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: const Text('Other income'),
        subtitle: const Text('Walk-ins and cash not booked through the app'),
        trailing: Text(
          summary.otherIncomeCents == 0 ? 'Add' : formatMoney(summary.otherIncomeCents, currency),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        onTap: () => _edit(context, ref),
      ),
    );
  }
}

/// What Premium adds, and the way in: a free trial first, then £9.99/month.
class _UpgradeCard extends ConsumerWidget {
  const _UpgradeCard({required this.state, required this.currency});

  final PremiumState state;

  /// Premium is billed in the shop's own currency.
  final String currency;

  Future<void> _subscribe(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await ref.read(billingActionControllerProvider.notifier).startFinanceCheckout();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final actionState = ref.watch(billingActionControllerProvider);
    const features = [
      (Icons.insights_outlined, 'Month-end forecast and the day you\'ll break even'),
      (Icons.lightbulb_outline, 'Offers worked out for your shop, with what they\'ll earn you'),
      (Icons.bar_chart, '12 months of profit history'),
      (Icons.grid_view, 'When your chairs are busy — and when they sit empty'),
      (Icons.content_cut, 'Each barber\'s bookings, revenue and how full they are'),
      (Icons.people_outline, 'Returning customers, and regulars you\'re losing'),
      (Icons.tune, 'What-if: try a price change before you make it'),
    ];
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.charcoal,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Finance Premium', style: textTheme.titleLarge?.copyWith(color: AppColors.chalk)),
            const SizedBox(height: 4),
            const Text('Your numbers, turned into decisions.', style: TextStyle(color: AppColors.chalk)),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                // Two columns once there's room, rather than one long, thin list.
                final itemWidth = constraints.maxWidth >= 640 ? (constraints.maxWidth - 24) / 2 : constraints.maxWidth;
                return Wrap(
                  spacing: 24,
                  children: [
                    for (final (icon, text) in features)
                      SizedBox(
                        width: itemWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(icon, color: AppColors.brass, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text(text, style: const TextStyle(color: AppColors.chalk))),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            if (!state.trialUsed)
              FilledButton(
                onPressed: actionState.isLoading
                    ? null
                    : () => ref.read(billingActionControllerProvider.notifier).startFinanceTrial(),
                child: const Text('Try it free for 14 days'),
              )
            else if (canPayInThisApp)
              FilledButton(onPressed: () => _subscribe(context, ref), child: Text('Get Premium — ${currencySymbol(currency)}9.99/month'))
            else
              const Center(child: PayOnWebsiteNote(color: AppColors.chalk)),
            const SizedBox(height: 6),
            Text(
              state.trialUsed ? 'Cancel anytime from Settings › Subscription & billing.' : 'No card needed for the trial.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: AppColors.chalk),
            ),
            if (actionState.hasError)
              Text(actionState.error.toString(), style: const TextStyle(color: Colors.redAccent)),
          ],
        ),
      ),
    );
  }
}
