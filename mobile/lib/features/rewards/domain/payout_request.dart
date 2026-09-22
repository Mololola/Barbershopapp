enum PayoutRequestStatus { pending, approved, rejected, paid }

extension PayoutRequestStatusX on PayoutRequestStatus {
  String get wireValue => name;

  static PayoutRequestStatus fromWireValue(String value) {
    return PayoutRequestStatus.values.firstWhere((status) => status.wireValue == value);
  }
}

/// A request to cash out reward_ledger earnings — a coordination record,
/// not a ledger itself. Money moves manually, outside the app; the admin
/// marks this 'paid' once they've actually sent it (see admin_screen.dart's
/// Payouts tab). `requesterUsername` is only populated for the admin's view
/// (their own requests don't need to name themselves).
class PayoutRequest {
  const PayoutRequest({
    required this.id,
    required this.profileId,
    required this.amountCents,
    required this.status,
    required this.requestedAt,
    this.resolvedAt,
    this.adminNote,
    this.requesterUsername,
  });

  final String id;
  final String profileId;
  final int amountCents;
  final PayoutRequestStatus status;
  final DateTime requestedAt;
  final DateTime? resolvedAt;
  final String? adminNote;
  final String? requesterUsername;

  factory PayoutRequest.fromRow(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    return PayoutRequest(
      id: row['id'] as String,
      profileId: row['profile_id'] as String,
      amountCents: row['amount_cents'] as int,
      status: PayoutRequestStatusX.fromWireValue(row['status'] as String),
      requestedAt: DateTime.parse(row['requested_at'] as String),
      resolvedAt: row['resolved_at'] != null ? DateTime.parse(row['resolved_at'] as String) : null,
      adminNote: row['admin_note'] as String?,
      requesterUsername: profile?['username'] as String?,
    );
  }
}
