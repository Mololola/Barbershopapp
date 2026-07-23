class WorkerProfile {
  const WorkerProfile({
    required this.profileId,
    required this.legalFirstName,
    required this.legalLastName,
    this.legalSecondLastName,
    this.bio,
    this.city,
    required this.isLookingForWork,
  });

  final String profileId;

  /// Real name, not the account username — shown to businesses so staff are
  /// identifiable by their actual name, not a handle.
  final String legalFirstName;
  final String legalLastName;
  final String? legalSecondLastName;

  final String? bio;
  final String? city;
  final bool isLookingForWork;

  String get legalFullName {
    final secondLastName = legalSecondLastName;
    if (secondLastName == null || secondLastName.isEmpty) {
      return '$legalFirstName $legalLastName';
    }
    return '$legalFirstName $legalLastName $secondLastName';
  }

  factory WorkerProfile.fromRow(Map<String, dynamic> row) {
    return WorkerProfile(
      profileId: row['profile_id'] as String,
      legalFirstName: row['legal_first_name'] as String,
      legalLastName: row['legal_last_name'] as String,
      legalSecondLastName: row['legal_second_last_name'] as String?,
      bio: row['bio'] as String?,
      city: row['city'] as String?,
      isLookingForWork: row['is_looking_for_work'] as bool,
    );
  }
}

/// A worker profile found by username, from a business's search — only ever
/// returned for profiles with `is_looking_for_work = true` (see worker_repository).
class WorkerSearchResult {
  const WorkerSearchResult({
    required this.profileId,
    required this.username,
    required this.legalFirstName,
    required this.legalLastName,
    this.legalSecondLastName,
    this.bio,
    this.city,
  });

  final String profileId;
  final String username;
  final String legalFirstName;
  final String legalLastName;
  final String? legalSecondLastName;
  final String? bio;
  final String? city;

  String get legalFullName {
    final secondLastName = legalSecondLastName;
    if (secondLastName == null || secondLastName.isEmpty) {
      return '$legalFirstName $legalLastName';
    }
    return '$legalFirstName $legalLastName $secondLastName';
  }
}
