import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n.dart';
import '../../../core/loading.dart';
import '../../../core/picked_media.dart';
import '../../customer/domain/public_business.dart';
import '../../customer/presentation/shop_page.dart';
import '../application/business_controller.dart';
import '../domain/brand.dart';

/// How the shop's page looks to customers: logo, cover photo and brand
/// colour, previewed live in the same header customers see.
class EditShopPageScreen extends ConsumerStatefulWidget {
  const EditShopPageScreen({super.key});

  @override
  ConsumerState<EditShopPageScreen> createState() => _EditShopPageScreenState();
}

class _EditShopPageScreenState extends ConsumerState<EditShopPageScreen> {
  XFile? _logo;
  XFile? _cover;
  Color? _brandColor;

  // Each capped near the largest size it's shown at: the logo is a small
  // circle, the cover a 2.5:1 header (see ShopHeader.heightFor).
  Future<XFile?> _pickLogo() =>
      ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);

  Future<XFile?> _pickCover() =>
      ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 640, imageQuality: 85);

  Future<void> _save() async {
    final brandColor = _brandColor;
    final success = await ref.read(shopBrandingControllerProvider.notifier).save(
          logoImage: _logo,
          coverImage: _cover,
          brandColor: brandColor == null ? null : brandColorToHex(brandColor),
        );
    if (success && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(currentBusinessProvider).value;
    final saveState = ref.watch(shopBrandingControllerProvider);
    final textTheme = Theme.of(context).textTheme;
    if (business == null) return const Scaffold(body: LoadingView());

    final current = _brandColor ?? brandColorOf(businessId: business.id, storedHex: business.brandColor);
    final hasChanges = _logo != null || _cover != null || _brandColor != null;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.editShopPage)),
      body: ListView(
        children: [
          ShopHeader(
            shop: PublicBusiness(
              id: business.id,
              ownerId: business.ownerId,
              name: business.name,
              currency: business.currency,
              logoUrl: business.logoUrl,
              coverUrl: business.coverUrl,
              brandColor: business.brandColor,
            ),
            logoImage: _logo == null ? null : pickedImage(_logo!),
            coverImage: _cover == null ? null : pickedImage(_cover!),
            brandColorOverride: _brandColor,
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.l10n.shopHeaderPreviewHint, style: textTheme.bodySmall),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.storefront_outlined),
                        label: Text(context.l10n.logo),
                        onPressed: () async {
                          final file = await _pickLogo();
                          if (file != null) setState(() => _logo = file);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.panorama_outlined),
                        label: Text(context.l10n.coverPhoto),
                        onPressed: () async {
                          final file = await _pickCover();
                          if (file != null) setState(() => _cover = file);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.coverSizeHint,
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                Text(context.l10n.brandColour, style: textTheme.titleMedium),
                Text(context.l10n.brandColourHint, style: textTheme.bodySmall),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final entry in brandPalette.entries)
                      Semantics(
                        label: entry.key,
                        selected: entry.value == current,
                        button: true,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => _brandColor = entry.value),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: entry.value,
                            child: entry.value == current ? const Icon(Icons.check, color: Colors.white) : null,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                if (saveState.hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      describeError(context.l10n, saveState.error),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                FilledButton(
                  onPressed: hasChanges && !saveState.isLoading ? _save : null,
                  child: saveState.isLoading
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(context.l10n.save),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
