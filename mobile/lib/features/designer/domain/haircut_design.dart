import 'hair_parameters.dart';

class HaircutDesign {
  const HaircutDesign({
    required this.id,
    required this.ownerId,
    this.ownerUsername,
    this.forkedFromId,
    required this.name,
    required this.parameters,
    this.thumbnailUrl,
    required this.isPublic,
    required this.createdAt,
  });

  final String id;
  final String ownerId;

  /// Populated client-side by joining against `profiles` — not every fetch
  /// needs it (e.g. "my designs" already knows the owner), so it's nullable.
  final String? ownerUsername;

  final String? forkedFromId;
  final String name;
  final HairParameters parameters;
  final String? thumbnailUrl;
  final bool isPublic;
  final DateTime createdAt;

  factory HaircutDesign.fromRow(Map<String, dynamic> row) {
    return HaircutDesign(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      ownerUsername: (row['profiles'] as Map<String, dynamic>?)?['username'] as String?,
      forkedFromId: row['forked_from_id'] as String?,
      name: row['name'] as String,
      parameters: HairParameters.fromJson(row['parameters'] as Map<String, dynamic>),
      thumbnailUrl: row['thumbnail_url'] as String?,
      isPublic: row['is_public'] as bool,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
