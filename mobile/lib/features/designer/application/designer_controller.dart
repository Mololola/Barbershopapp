import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/designer_repository.dart';
import '../domain/haircut_design.dart';
import '../domain/hair_parameters.dart';

/// Free-tier cap on saved designs, per the spec ("save up to 3... pay for
/// extra space"). Enforced client-side only — there's no way to actually
/// pay for more yet (that's the Stripe billing milestone), so there's
/// nothing money-adjacent to protect server-side until that exists.
const maxFreeDesigns = 3;

final designerRepositoryProvider = Provider<DesignerRepository>((ref) {
  return DesignerRepository(ref.watch(supabaseClientProvider));
});

/// autoDispose — same cross-account staleness reasoning as rankings and the
/// worker marketplace: re-fetch every time the gallery is opened.
final myDesignsProvider = FutureProvider.autoDispose<List<HaircutDesign>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.watch(designerRepositoryProvider).fetchMyDesigns(profile.id);
});

final publicDesignsProvider = FutureProvider.autoDispose<List<HaircutDesign>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.watch(designerRepositoryProvider).fetchPublicDesigns(profile.id);
});

final designProvider = FutureProvider.autoDispose.family<HaircutDesign?, String>((ref, designId) {
  return ref.watch(designerRepositoryProvider).fetchDesign(designId);
});

class DesignSaveResult {
  const DesignSaveResult.success(this.designId) : capReached = false;

  const DesignSaveResult.capReached()
      : designId = null,
        capReached = true;

  final String? designId;
  final bool capReached;
}

final designEditControllerProvider =
    AsyncNotifierProvider<DesignEditController, void>(DesignEditController.new);

class DesignEditController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<DesignSaveResult> saveNewDesign({
    required String name,
    required HairParameters parameters,
    Uint8List? thumbnailPngBytes,
    String? forkedFromId,
  }) async {
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null) throw StateError('Not signed in.');

    final existing = await ref.read(designerRepositoryProvider).fetchMyDesigns(profile.id);
    if (existing.length >= maxFreeDesigns) {
      return const DesignSaveResult.capReached();
    }

    var result = const DesignSaveResult.capReached();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(designerRepositoryProvider);
      final designId = await repository.createDesign(
        ownerId: profile.id,
        name: name,
        parameters: parameters,
        forkedFromId: forkedFromId,
      );
      if (thumbnailPngBytes != null) {
        final url = await repository.uploadThumbnail(profile.id, designId, thumbnailPngBytes);
        await repository.updateDesign(designId, thumbnailUrl: url);
      }
      ref.invalidate(myDesignsProvider);
      result = DesignSaveResult.success(designId);
    });
    return result;
  }

  Future<void> updateDesign({
    required String designId,
    String? name,
    HairParameters? parameters,
    Uint8List? thumbnailPngBytes,
    bool? isPublic,
  }) async {
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null) throw StateError('Not signed in.');
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(designerRepositoryProvider);
      String? thumbnailUrl;
      if (thumbnailPngBytes != null) {
        thumbnailUrl = await repository.uploadThumbnail(profile.id, designId, thumbnailPngBytes);
      }
      await repository.updateDesign(
        designId,
        name: name,
        parameters: parameters,
        thumbnailUrl: thumbnailUrl,
        isPublic: isPublic,
      );
      ref.invalidate(myDesignsProvider);
      ref.invalidate(designProvider(designId));
    });
  }

  Future<void> deleteDesign(String designId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(designerRepositoryProvider).deleteDesign(designId);
      ref.invalidate(myDesignsProvider);
    });
  }

  Future<DesignSaveResult> forkDesign(HaircutDesign source) async {
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null) throw StateError('Not signed in.');

    final existing = await ref.read(designerRepositoryProvider).fetchMyDesigns(profile.id);
    if (existing.length >= maxFreeDesigns) {
      return const DesignSaveResult.capReached();
    }

    var result = const DesignSaveResult.capReached();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(designerRepositoryProvider);
      final designId = await repository.createDesign(
        ownerId: profile.id,
        name: '${source.name} (fork)',
        parameters: source.parameters,
        forkedFromId: source.id,
      );
      if (source.thumbnailUrl != null) {
        await repository.updateDesign(designId, thumbnailUrl: source.thumbnailUrl);
      }
      ref.invalidate(myDesignsProvider);
      result = DesignSaveResult.success(designId);
    });
    return result;
  }
}
