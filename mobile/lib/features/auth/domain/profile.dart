enum AccountRole { customer, business }

extension AccountRoleX on AccountRole {
  String get wireValue => name;

  static AccountRole fromWireValue(String value) {
    return AccountRole.values.firstWhere((role) => role.wireValue == value);
  }
}

class Profile {
  const Profile({
    required this.id,
    required this.role,
    required this.username,
    required this.referralCode,
    this.avatarUrl,
    this.isAdmin = false,
    this.isQualityReviewer = false,
    this.dateOfBirth,
    this.isMinor = false,
  });

  final String id;
  final AccountRole role;
  final String username;

  /// Shared with businesses at signup to be credited for the referral —
  /// meant to be given out, not sensitive (see ranking_referrals()).
  final String referralCode;

  final String? avatarUrl;

  /// Only ever set via direct DB access, never through the app — gates the
  /// Admin screen.
  final bool isAdmin;

  /// Set by an admin, per-account — makes this customer's future review
  /// rewards pay the higher tier (see backend/app/api/rewards.py).
  final bool isQualityReviewer;

  /// Set once at signup, then locked from self-editing at the DB level
  /// (see the 832ca4a41b29 migration) — never client-supplied after that.
  final DateTime? dateOfBirth;

  /// Server-computed (the `profile_is_minor` SQL function) rather than
  /// derived client-side from [dateOfBirth], so the client and the RLS
  /// policies that actually enforce the restrictions always agree.
  final bool isMinor;

  factory Profile.fromRow(Map<String, dynamic> row) {
    return Profile(
      id: row['id'] as String,
      role: AccountRoleX.fromWireValue(row['role'] as String),
      username: row['username'] as String,
      referralCode: row['referral_code'] as String,
      avatarUrl: row['avatar_url'] as String?,
      isAdmin: row['is_admin'] as bool? ?? false,
      isQualityReviewer: row['is_quality_reviewer'] as bool? ?? false,
      dateOfBirth: row['date_of_birth'] != null ? DateTime.parse(row['date_of_birth'] as String) : null,
      isMinor: row['is_minor'] as bool? ?? false,
    );
  }
}
