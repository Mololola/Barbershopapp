enum LeaveRequestStatus { pending, acknowledged }

extension LeaveRequestStatusX on LeaveRequestStatus {
  String get wireValue => name;

  static LeaveRequestStatus fromWireValue(String value) {
    return LeaveRequestStatus.values.firstWhere((status) => status.wireValue == value);
  }
}

/// A worker's request to leave their current job — the worker doesn't
/// actually leave until the business acknowledges it (see
/// business_repository.dart's `acknowledgeLeaveRequest`, which resolves this
/// row and deactivates the `workers` row together).
class WorkerLeaveRequest {
  const WorkerLeaveRequest({
    required this.id,
    required this.workerId,
    required this.businessId,
    required this.workerProfileId,
    required this.businessName,
    required this.status,
    required this.requestedAt,
    this.resolvedAt,
  });

  final String id;
  final String workerId;
  final String businessId;
  final String workerProfileId;

  /// Denormalized onto the row at creation — same reasoning as
  /// worker_invitations.business_name (658403671135).
  final String businessName;

  final LeaveRequestStatus status;
  final DateTime requestedAt;
  final DateTime? resolvedAt;

  factory WorkerLeaveRequest.fromRow(Map<String, dynamic> row) {
    return WorkerLeaveRequest(
      id: row['id'] as String,
      workerId: row['worker_id'] as String,
      businessId: row['business_id'] as String,
      workerProfileId: row['worker_profile_id'] as String,
      businessName: row['business_name'] as String,
      status: LeaveRequestStatusX.fromWireValue(row['status'] as String),
      requestedAt: DateTime.parse(row['requested_at'] as String),
      resolvedAt: row['resolved_at'] != null ? DateTime.parse(row['resolved_at'] as String) : null,
    );
  }
}
