import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/haircut_design.dart';
import '../domain/hair_parameters.dart';

/// Raised when the Postgres trigger (not just the client-side pre-check)
/// rejects an insert past the free-plus-purchased design cap — see
/// enforce_design_slot_cap() in the design_extra_slots migration. Thrown as
/// a defense-in-depth backstop; the UI should rarely hit this since
/// [DesignEditController] checks the cap before inserting.
class DesignSlotCapReachedException implements Exception {
  @override
  String toString() => 'Design slot cap reached.';
}

class DesignerRepository {
  DesignerRepository(this._client);

  static const _designSlotCapErrorCode = 'P0001';

  final SupabaseClient _client;

  Future<int> fetchExtraSlots(String profileId) async {
    final row = await _client
        .from('design_extra_slots')
        .select('extra_slots')
        .eq('profile_id', profileId)
        .maybeSingle();
    return row == null ? 0 : row['extra_slots'] as int;
  }

  Future<List<HaircutDesign>> fetchMyDesigns(String ownerId) async {
    final rows = await _client
        .from('haircut_designs')
        .select()
        .eq('owner_id', ownerId)
        .order('created_at', ascending: true);
    return rows.map(HaircutDesign.fromRow).toList();
  }

  /// Every account's own designs are also `is_public = true`-eligible, so
  /// this excludes mine — "Browse" is for discovering *other* people's work.
  Future<List<HaircutDesign>> fetchPublicDesigns(String excludingOwnerId) async {
    final rows = await _client
        .from('haircut_designs')
        .select('*, profiles(username)')
        .eq('is_public', true)
        .neq('owner_id', excludingOwnerId)
        .order('created_at', ascending: false);
    return rows.map(HaircutDesign.fromRow).toList();
  }

  Future<HaircutDesign?> fetchDesign(String designId) async {
    final row = await _client
        .from('haircut_designs')
        .select('*, profiles(username)')
        .eq('id', designId)
        .maybeSingle();
    if (row == null) return null;
    return HaircutDesign.fromRow(row);
  }

  Future<String> createDesign({
    required String ownerId,
    required String name,
    required HairParameters parameters,
    String? forkedFromId,
    bool isPublic = false,
  }) async {
    try {
      final rows = await _client.from('haircut_designs').insert({
        'owner_id': ownerId,
        'name': name,
        'parameters': parameters.toJson(),
        'forked_from_id': forkedFromId,
        'is_public': isPublic,
      }).select();
      return rows.first['id'] as String;
    } on PostgrestException catch (e) {
      if (e.code == _designSlotCapErrorCode) throw DesignSlotCapReachedException();
      rethrow;
    }
  }

  Future<void> updateDesign(
    String designId, {
    String? name,
    HairParameters? parameters,
    String? thumbnailUrl,
    bool? isPublic,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (parameters != null) updates['parameters'] = parameters.toJson();
    if (thumbnailUrl != null) updates['thumbnail_url'] = thumbnailUrl;
    if (isPublic != null) updates['is_public'] = isPublic;
    if (updates.isEmpty) return;
    await _client.from('haircut_designs').update(updates).eq('id', designId);
  }

  Future<void> deleteDesign(String designId) async {
    await _client.from('haircut_designs').delete().eq('id', designId);
  }

  /// Uploaded to a fresh path per save (unlike the avatar's upsert-in-place
  /// pattern) since each design keeps its own thumbnail history-free — a
  /// re-save just points `thumbnail_url` at the new path.
  Future<String> uploadThumbnail(String ownerId, String designId, Uint8List pngBytes) async {
    final path = '$ownerId/$designId-${DateTime.now().millisecondsSinceEpoch}.png';
    await _client.storage.from('haircut-thumbnails').uploadBinary(
          path,
          pngBytes,
          fileOptions: const FileOptions(contentType: 'image/png'),
        );
    return _client.storage.from('haircut-thumbnails').getPublicUrl(path);
  }

  /// Decodes a `data:image/png;base64,...` URL from the WebView's
  /// `canvas.toDataURL()` into raw bytes for [uploadThumbnail].
  static Uint8List decodeDataUrl(String dataUrl) {
    final commaIndex = dataUrl.indexOf(',');
    final base64Part = commaIndex == -1 ? dataUrl : dataUrl.substring(commaIndex + 1);
    return base64Decode(base64Part);
  }
}
