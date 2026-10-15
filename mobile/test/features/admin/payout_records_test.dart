import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/admin/domain/payout_records.dart';
import 'package:mobile/features/rewards/domain/payout_request.dart';

PayoutRequest _request(
  String id,
  int cents,
  String currency,
  DateTime paidOn, {
  PayoutRequestStatus status = PayoutRequestStatus.paid,
  String? profileId = 'p1',
}) =>
    PayoutRequest(
      id: id,
      profileId: profileId,
      amountCents: cents,
      currency: currency,
      status: status,
      requestedAt: paidOn.subtract(const Duration(days: 2)),
      resolvedAt: paidOn,
      accountHolder: 'Ana "AR" Ruiz',
      iban: 'ES9121000418450200051332',
      requesterUsername: 'ana',
    );

void main() {
  final records = PayoutRecords([
    _request('aaaaaaaa-1', 1000, 'GBP', DateTime(2026, 10, 3)),
    _request('bbbbbbbb-2', 500, 'GBP', DateTime(2026, 9, 20)),
    _request('cccccccc-3', 250, 'EUR', DateTime(2026, 10, 9), profileId: null),
    _request('dddddddd-4', 700, 'GBP', DateTime(2025, 12, 1)),
    _request('eeeeeeee-5', 9999, 'GBP', DateTime(2026, 10, 5), status: PayoutRequestStatus.approved),
  ]);

  test('only payouts marked paid count, newest first', () {
    expect(records.paid.map((r) => r.id), ['cccccccc-3', 'aaaaaaaa-1', 'bbbbbbbb-2', 'dddddddd-4']);
    expect(records.years, [2026, 2025]);
  });

  test('totals by month, year and all time, each currency on its own', () {
    expect(records.monthTotals(DateTime(2026, 10)), {'GBP': 1000, 'EUR': 250});
    expect(records.yearTotals(2026), {'GBP': 1500, 'EUR': 250});
    expect(records.totals(), {'GBP': 2200, 'EUR': 250});
  });

  test('the CSV register lists the year oldest first, quoting names', () {
    final lines = records.csv(2026).split('\n');
    expect(lines.first, 'Date paid,Reference,Payee,Username,IBAN,Amount,Currency');
    expect(lines.length, 4);
    expect(lines[1], '2026-09-20,BBBBBBBB,"Ana ""AR"" Ruiz","ana",ES9121000418450200051332,5.00,GBP');
  });
}
