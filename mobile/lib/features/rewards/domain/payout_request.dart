enum PayoutRequestStatus { pending, approved, rejected, paid }

extension PayoutRequestStatusX on PayoutRequestStatus {
  String get wireValue => name;

  static PayoutRequestStatus fromWireValue(String value) {
    return PayoutRequestStatus.values.firstWhere((status) => status.wireValue == value);
  }
}

/// A request to cash out reward_ledger earnings in one currency — a
/// coordination record, not a ledger itself. Money moves by bank transfer,
/// outside the app, to the account copied onto the request when it was made
/// (`accountHolder`/`iban`; null on requests from before bank details
/// existed); the admin marks this 'paid' once they've actually sent it (see
/// admin_screen.dart's Payouts tab). `requesterUsername` is only populated
/// for the admin's view (their own requests don't need to name themselves).
/// A paid request outlives its account (a tax record): `profileId` is then
/// null and `requesterUsername` comes from the copy taken when it was made.
class PayoutRequest {
  const PayoutRequest({
    required this.id,
    required this.profileId,
    required this.amountCents,
    required this.currency,
    required this.status,
    required this.requestedAt,
    this.accountHolder,
    this.iban,
    this.resolvedAt,
    this.adminNote,
    this.requesterUsername,
  });

  final String id;
  final String? profileId;
  final int amountCents;
  final String currency;
  final String? accountHolder;
  final String? iban;
  final PayoutRequestStatus status;
  final DateTime requestedAt;
  final DateTime? resolvedAt;
  final String? adminNote;
  final String? requesterUsername;

  factory PayoutRequest.fromRow(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    return PayoutRequest(
      id: row['id'] as String,
      profileId: row['profile_id'] as String?,
      amountCents: row['amount_cents'] as int,
      currency: row['currency'] as String,
      accountHolder: row['account_holder'] as String?,
      iban: row['iban'] as String?,
      status: PayoutRequestStatusX.fromWireValue(row['status'] as String),
      requestedAt: DateTime.parse(row['requested_at'] as String),
      resolvedAt: row['resolved_at'] != null ? DateTime.parse(row['resolved_at'] as String) : null,
      adminNote: row['admin_note'] as String?,
      requesterUsername: profile?['username'] as String? ?? row['requester_username'] as String?,
    );
  }
}
