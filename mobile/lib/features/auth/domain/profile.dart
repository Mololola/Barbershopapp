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
  });

  final String id;
  final AccountRole role;
  final String username;

  /// Shared with businesses at signup to be credited for the referral —
  /// meant to be given out, not sensitive (see ranking_referrals()).
  final String referralCode;

  final String? avatarUrl;

  factory Profile.fromRow(Map<String, dynamic> row) {
    return Profile(
      id: row['id'] as String,
      role: AccountRoleX.fromWireValue(row['role'] as String),
      username: row['username'] as String,
      referralCode: row['referral_code'] as String,
      avatarUrl: row['avatar_url'] as String?,
    );
  }
}
