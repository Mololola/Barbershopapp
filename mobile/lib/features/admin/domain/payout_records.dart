import '../../rewards/domain/payout_request.dart';

/// Money actually paid out, for the admin's accounts and any tax audit.
/// Dated by when it was marked paid, in the admin's time zone; totals are
/// per currency and never converted.
class PayoutRecords {
  PayoutRecords(Iterable<PayoutRequest> requests)
      : paid = requests.where((request) => request.status == PayoutRequestStatus.paid).toList()
          ..sort((a, b) => paidOn(b).compareTo(paidOn(a)));

  /// Newest first.
  final List<PayoutRequest> paid;

  /// Marking it paid is its last resolution, so resolvedAt is the payment date.
  static DateTime paidOn(PayoutRequest request) => (request.resolvedAt ?? request.requestedAt).toLocal();

  /// A short, stable reference to quote for a payment.
  static String reference(PayoutRequest request) => request.id.substring(0, 8).toUpperCase();

  /// Newest first.
  List<int> get years => {for (final request in paid) paidOn(request).year}.toList()..sort((a, b) => b - a);

  List<PayoutRequest> inYear(int year) => [for (final request in paid) if (paidOn(request).year == year) request];

  Map<String, int> totals([bool Function(DateTime paidOn)? when]) {
    final totals = <String, int>{};
    for (final request in paid) {
      if (when != null && !when(paidOn(request))) continue;
      totals.update(request.currency, (cents) => cents + request.amountCents, ifAbsent: () => request.amountCents);
    }
    return totals;
  }

  Map<String, int> monthTotals(DateTime month) =>
      totals((date) => date.year == month.year && date.month == month.month);

  Map<String, int> yearTotals(int year) => totals((date) => date.year == year);

  /// The year's register, oldest first, for an accountant's spreadsheet.
  String csv(int year) {
    String field(String? value) => '"${(value ?? '').replaceAll('"', '""')}"';
    final lines = ['Date paid,Reference,Payee,Username,IBAN,Amount,Currency'];
    for (final request in inYear(year).reversed) {
      final date = paidOn(request);
      lines.add([
        '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}',
        reference(request),
        field(request.accountHolder),
        field(request.requesterUsername ?? 'Deleted account'),
        request.iban ?? '',
        (request.amountCents / 100).toStringAsFixed(2),
        request.currency,
      ].join(','));
    }
    return lines.join('\n');
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
