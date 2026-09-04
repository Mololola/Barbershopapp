class WorkerProfile {
  const WorkerProfile({
    required this.profileId,
    required this.legalFirstName,
    required this.legalLastName,
    this.legalSecondLastName,
    this.bio,
    this.city,
    this.yearsExperience,
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

  /// Structured, unlike `bio` — the marketplace filters on this, so it has
  /// to be a comparable number rather than whatever a free-text bio says.
  final int? yearsExperience;

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
      yearsExperience: row['years_experience'] as int?,
      isLookingForWork: row['is_looking_for_work'] as bool,
    );
  }
}

/// A worker profile found on a business's marketplace search — only ever
/// returned for profiles with `is_looking_for_work = true` and no active job
/// (see business_repository.dart). `shopsWorkedCount`/`averageRating` are
/// server-computed aggregates (see the `worker_shops_worked_count`/
/// `worker_average_rating` SQL functions) — never client-supplied, so a
/// candidate can't inflate their own standing.
class WorkerSearchResult {
  const WorkerSearchResult({
    required this.profileId,
    required this.username,
    required this.legalFirstName,
    required this.legalLastName,
    this.legalSecondLastName,
    this.bio,
    this.city,
    this.yearsExperience,
    this.shopsWorkedCount,
    this.averageRating,
  });

  final String profileId;
  final String username;
  final String legalFirstName;
  final String legalLastName;
  final String? legalSecondLastName;
  final String? bio;
  final String? city;
  final int? yearsExperience;
  final int? shopsWorkedCount;
  final double? averageRating;

  String get legalFullName {
    final secondLastName = legalSecondLastName;
    if (secondLastName == null || secondLastName.isEmpty) {
      return '$legalFirstName $legalLastName';
    }
    return '$legalFirstName $legalLastName $secondLastName';
  }
}
