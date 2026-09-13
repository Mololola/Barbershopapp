enum GuardianLinkStatus { pending, confirmed }

extension GuardianLinkStatusX on GuardianLinkStatus {
  String get wireValue => name;

  static GuardianLinkStatus fromWireValue(String value) {
    return GuardianLinkStatus.values.firstWhere((status) => status.wireValue == value);
  }
}

/// A minor's invitation to a parent/guardian, and that guardian's
/// confirmation of it — the verifiable-consent mechanism required before a
/// minor's account unlocks beyond the consent screen (see the
/// 832ca4a41b29 migration and its `profile_guardian_links` table).
class GuardianLink {
  const GuardianLink({
    required this.id,
    required this.minorProfileId,
    required this.guardianEmail,
    required this.status,
    this.guardianProfileId,
    this.consentedAt,
  });

  final String id;
  final String minorProfileId;
  final String guardianEmail;
  final GuardianLinkStatus status;
  final String? guardianProfileId;
  final DateTime? consentedAt;

  factory GuardianLink.fromRow(Map<String, dynamic> row) {
    return GuardianLink(
      id: row['id'] as String,
      minorProfileId: row['minor_profile_id'] as String,
      guardianEmail: row['guardian_email'] as String,
      status: GuardianLinkStatusX.fromWireValue(row['status'] as String),
      guardianProfileId: row['guardian_profile_id'] as String?,
      consentedAt: row['consented_at'] != null ? DateTime.parse(row['consented_at'] as String) : null,
    );
  }
}
