import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/loading.dart';
import '../../../core/responsive.dart';
import '../../business/domain/finance_overview.dart';
import '../application/admin_controller.dart';
import '../domain/payout_records.dart';

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _date(DateTime date) => '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

/// "£40.00 · €12.50", or "—" with nothing paid.
String _perCurrency(Map<String, int> totals) => totals.isEmpty
    ? '—'
    : (totals.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        .map((total) => formatMoney(total.value, total.key))
        .join(' · ');

/// Admin › Payouts › Records: what has been paid out — by month, year and
/// all time — and the year's register, kept after accounts are deleted.
class AdminPayoutRecords extends ConsumerStatefulWidget {
  const AdminPayoutRecords({super.key});

  @override
  ConsumerState<AdminPayoutRecords> createState() => _AdminPayoutRecordsState();
}

class _AdminPayoutRecordsState extends ConsumerState<AdminPayoutRecords> {
  int? _year;

  void _copyCsv(PayoutRecords records, int year) {
    Clipboard.setData(ClipboardData(text: records.csv(year)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$year register copied — paste it into a spreadsheet')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(adminPayoutRequestsProvider);
    final textTheme = Theme.of(context).textTheme;

    return requests.when(
      loading: () => const LoadingView(),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (list) {
        final records = PayoutRecords(list);
        if (records.paid.isEmpty) return const Center(child: Text('No payouts made yet.'));
        final now = DateTime.now();
        final year = _year ?? records.years.first;
        final register = records.inYear(year);
        final months = [
          for (var month = 12; month >= 1; month--)
            if (register.any((request) => PayoutRecords.paidOn(request).month == month)) month,
        ];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Payout records', style: textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Rewards paid to users, dated when marked paid. Kept when an account is deleted, as a record for '
              'tax and accounting. Each currency is totalled separately.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ResponsiveColumns(
              minChildWidth: 200,
              spacing: 12,
              children: [
                _Total(label: 'This month · ${_monthNames[now.month - 1]} ${now.year}', value: _perCurrency(records.monthTotals(now))),
                _Total(label: 'This year · ${now.year}', value: _perCurrency(records.yearTotals(now.year))),
                _Total(label: 'All time · ${records.paid.length} payouts', value: _perCurrency(records.totals())),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Year', style: textTheme.titleMedium),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: year,
                  items: [for (final y in records.years) DropdownMenuItem(value: y, child: Text('$y'))],
                  onChanged: (value) => setState(() => _year = value),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _copyCsv(records, year),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy CSV'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Section(
              title: 'Monthly totals, $year',
              trailing: 'Year total: ${_perCurrency(records.yearTotals(year))}',
              table: DataTable(
                columns: const [
                  DataColumn(label: Text('Month')),
                  DataColumn(label: Text('Payouts'), numeric: true),
                  DataColumn(label: Text('Total'), numeric: true),
                ],
                rows: [
                  for (final month in months)
                    DataRow(cells: [
                      DataCell(Text('${_monthNames[month - 1]} $year')),
                      DataCell(Text(
                        '${register.where((request) => PayoutRecords.paidOn(request).month == month).length}',
                      )),
                      DataCell(Text(_perCurrency(records.monthTotals(DateTime(year, month))))),
                    ]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Register, $year',
              trailing: '${register.length} payouts',
              table: DataTable(
                columns: const [
                  DataColumn(label: Text('Date paid')),
                  DataColumn(label: Text('Reference')),
                  DataColumn(label: Text('Paid to')),
                  DataColumn(label: Text('Account')),
                  DataColumn(label: Text('IBAN')),
                  DataColumn(label: Text('Amount'), numeric: true),
                ],
                rows: [
                  for (final request in register)
                    DataRow(cells: [
                      DataCell(Text(_date(PayoutRecords.paidOn(request)))),
                      DataCell(SelectableText(PayoutRecords.reference(request))),
                      DataCell(Text(request.accountHolder ?? '—')),
                      DataCell(Text(
                        request.profileId == null
                            ? '${request.requesterUsername ?? 'Unknown'} (deleted)'
                            : request.requesterUsername ?? '—',
                      )),
                      DataCell(SelectableText(request.iban ?? '—')),
                      DataCell(Text(formatMoney(request.amountCents, request.currency))),
                    ]),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(value, style: textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}

/// A titled table; on a phone the table scrolls sideways inside the card.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.trailing, required this.table});

  final String title;
  final String trailing;
  final Widget table;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  Text(trailing, style: textTheme.bodySmall),
                ],
              ),
            ),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: table),
          ],
        ),
      ),
    );
  }
}
