enum InvitationStatus { pending, accepted, declined }

extension InvitationStatusX on InvitationStatus {
  String get wireValue => name;

  static InvitationStatus fromWireValue(String value) {
    return InvitationStatus.values.firstWhere((status) => status.wireValue == value);
  }
}

class WorkerInvitation {
  const WorkerInvitation({
    required this.id,
    required this.businessId,
    required this.workerProfileId,
    required this.status,
    required this.businessName,
    required this.createdAt,
    this.workerUsername,
    this.workerLegalFullName,
  });

  final String id;
  final String businessId;
  final String workerProfileId;
  final InvitationStatus status;
  final DateTime createdAt;

  /// Denormalized onto the row at invite creation (see the migration) rather
  /// than embedded from `businesses` — a cross-table RLS policy for that
  /// caused infinite recursion, since `businesses` and `worker_invitations`
  /// policies would each query the other.
  final String businessName;

  /// Populated when fetched from the business's side (embedded `profiles.username`
  /// and, when readable under RLS, the nested `worker_profiles` legal name).
  final String? workerUsername;
  final String? workerLegalFullName;

  factory WorkerInvitation.fromRow(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    final workerProfile = profile?['worker_profiles'] as Map<String, dynamic>?;

    String? legalFullName;
    if (workerProfile != null) {
      final firstName = workerProfile['legal_first_name'] as String?;
      final lastName = workerProfile['legal_last_name'] as String?;
      final secondLastName = workerProfile['legal_second_last_name'] as String?;
      if (firstName != null && lastName != null) {
        legalFullName = [
          firstName,
          lastName,
          if (secondLastName != null && secondLastName.isNotEmpty) secondLastName,
        ].join(' ');
      }
    }

    return WorkerInvitation(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      workerProfileId: row['worker_profile_id'] as String,
      status: InvitationStatusX.fromWireValue(row['status'] as String),
      businessName: row['business_name'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      workerUsername: profile?['username'] as String?,
      workerLegalFullName: legalFullName,
    );
  }
}
