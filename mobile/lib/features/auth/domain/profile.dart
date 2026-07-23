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
    this.avatarUrl,
  });

  final String id;
  final AccountRole role;
  final String username;
  final String? avatarUrl;

  factory Profile.fromRow(Map<String, dynamic> row) {
    return Profile(
      id: row['id'] as String,
      role: AccountRoleX.fromWireValue(row['role'] as String),
      username: row['username'] as String,
      avatarUrl: row['avatar_url'] as String?,
    );
  }
}
