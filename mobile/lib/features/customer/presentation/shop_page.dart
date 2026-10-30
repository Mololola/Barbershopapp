import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../core/skeleton.dart';
import '../../../core/theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../business/domain/brand.dart';
import '../../business/domain/business.dart';
import '../../feed/application/feed_controller.dart';
import '../../feed/presentation/post_card.dart';
import '../../messaging/application/messaging_controller.dart';
import '../application/browse_controller.dart';
import '../domain/public_business.dart';
import '../domain/shop_review.dart';

/// A shop's public page — what customers choose between, and (with
/// [isOwner]) the business's own Profile tab, so the owner always sees
/// exactly what customers see.
class ShopPage extends ConsumerWidget {
  const ShopPage({super.key, required this.businessId, this.isOwner = false});

  final String businessId;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(businessProvider(businessId));

    return Scaffold(
      body: business.when(
        loading: () => ListView(
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            SkeletonPulse(child: SkeletonBox(height: 200, radius: 0)),
            Padding(padding: EdgeInsets.all(20), child: SkeletonLines(count: 4)),
          ],
        ),
        error: (error, _) => Center(child: Text(describeError(context.l10n, error))),
        data: (shop) {
          if (shop == null) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    isOwner
                        ? context.l10n.shopHiddenOwner
                        : context.l10n.shopUnavailable,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(businessProvider(businessId));
              ref.invalidate(businessReviewsProvider(businessId));
              ref.invalidate(postsByAuthorProvider(shop.ownerId));
            },
            child: LayoutBuilder(
              builder: (context, constraints) => CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: ShopHeader.heightFor(constraints.maxWidth),
                    backgroundColor: brandColorOf(businessId: shop.id, storedHex: shop.brandColor),
                    foregroundColor: Colors.white,
                    // The website's light header theme gives titles a dark colour of their own.
                    titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(color: Colors.white),
                    title: Text(shop.name),
                    actions: [
                      if (isOwner)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: context.l10n.editShopPage,
                          onPressed: () => context.push('/business/shop/edit'),
                        ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(background: ShopHeader(shop: shop)),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    sliver: SliverList.list(children: [_ShopBody(shop: shop, isOwner: isOwner)]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Cover photo (or the brand colour with a stripe pattern when there's
/// none) with the logo — or the shop's initials — overlapping its bottom.
/// Public so the shop-page editor can preview changes live.
class ShopHeader extends StatelessWidget {
  const ShopHeader({
    super.key,
    required this.shop,
    this.coverImage,
    this.logoImage,
    this.brandColorOverride,
  });

  /// Covers are made at 2.5:1 (the editor asks for 1600 × 640), so the
  /// header keeps that shape — a phone shows the whole photo instead of
  /// cutting its sides — within limits that leave room for the title and
  /// logo, and stop it taking over a wide screen.
  static double heightFor(double width) => (width / 2.5).clamp(180.0, 360.0);

  final PublicBusiness shop;

  /// Unsaved picks in the editor, shown in place of the stored ones.
  final ImageProvider? coverImage;
  final ImageProvider? logoImage;
  final Color? brandColorOverride;

  @override
  Widget build(BuildContext context) {
    final brand = brandColorOverride ?? brandColorOf(businessId: shop.id, storedHex: shop.brandColor);
    final cover = coverImage ?? (shop.coverUrl != null ? CachedNetworkImageProvider(shop.coverUrl!) : null);
    final logo = logoImage ?? (shop.logoUrl != null ? CachedNetworkImageProvider(shop.logoUrl!) : null);
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: heightFor(constraints.maxWidth),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cover != null)
              Image(image: cover, fit: BoxFit.cover)
            else
              CustomPaint(painter: _StripePainter(brand)),
            // Keeps the app-bar title and back button readable over any photo.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x66000000), Color(0x00000000), Color(0x80000000)],
                ),
              ),
            ),
            Positioned(
              left: 20,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: brand,
                  backgroundImage: logo,
                  child: logo == null
                      ? Text(
                          initialsOf(shop.name),
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The default cover: the brand colour with faint diagonal stripes — a nod
/// to a barber's pole rather than a flat block.
class _StripePainter extends CustomPainter {
  _StripePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    final stripe = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 18;
    for (var x = -size.height; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), stripe);
    }
  }

  @override
  bool shouldRepaint(_StripePainter oldDelegate) => oldDelegate.color != color;
}

class _ShopBody extends ConsumerWidget {
  const _ShopBody({required this.shop, required this.isOwner});

  final PublicBusiness shop;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final hours = ref.watch(businessOpeningHoursProvider(shop.id)).value;
    final locations = ref.watch(businessLocationsProvider(shop.id)).value ?? const [];
    final myProfile = ref.watch(currentProfileProvider).value;
    final brand = brandColorOf(businessId: shop.id, storedHex: shop.brandColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (shop.averageRating != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: AppColors.brass, size: 20),
                  Text(' ${shop.averageRating}', style: textTheme.titleMedium),
                  Text(' (${shop.reviewCount})', style: const TextStyle(color: AppColors.steel)),
                ],
              )
            else
              Text(context.l10n.newOnTheApp, style: const TextStyle(color: AppColors.steel)),
            if (hours != null) _OpenNow(hours: hours),
          ],
        ),
        if (locations.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            locations.first.displayAddress + (locations.length > 1 ? ' · ${context.l10n.moreLocations(locations.length - 1)}' : ''),
            style: const TextStyle(color: AppColors.steel),
          ),
        ],
        const SizedBox(height: 16),
        if (isOwner)
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: Colors.white),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(context.l10n.newPost),
                  onPressed: () => context.push('/posts/new'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.brush_outlined),
                  label: Text(context.l10n.editPage),
                  onPressed: () => context.push('/business/shop/edit'),
                ),
              ),
            ],
          )
        // No DMs to or from a minor account — see the guardian-consent design.
        else if (myProfile != null && myProfile.isMinor != true)
          OutlinedButton.icon(
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(context.l10n.messageTheShop),
            onPressed: () async {
              final conversationId =
                  await ref.read(messagingActionControllerProvider.notifier).startOrGetConversation(shop.ownerId);
              if (context.mounted) context.push('/messages/$conversationId');
            },
          ),
        _Section(title: context.l10n.services, child: _Services(shop: shop, isOwner: isOwner, brand: brand)),
        _Section(title: context.l10n.barbers, child: _Barbers(businessId: shop.id, brand: brand)),
        if (hours != null)
          _Section(
            title: context.l10n.openingHours,
            child: Column(
              children: [
                for (final day in hours)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(child: Text(context.weekdayName(day.dayOfWeek))),
                        Text(day.format(context)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (locations.length > 1)
          _Section(
            title: context.l10n.locations,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final l in locations) Text(l.displayAddress)],
            ),
          ),
        _Section(title: context.l10n.posts, child: _Posts(ownerId: shop.ownerId)),
        _Section(title: context.l10n.reviews, child: _Reviews(businessId: shop.id)),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// "Open now · until 18:00", "Opens 16:00" (during a break or before
/// opening), or "Closed today" — in the device's time, which for a local
/// customer is the shop's.
class _OpenNow extends StatelessWidget {
  const _OpenNow({required this.hours});

  final List<OpeningHours> hours;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = hours.where((h) => h.dayOfWeek == now.weekday - 1).firstOrNull;
    int minutes(TimeOfDay t) => t.hour * 60 + t.minute;
    final nowMinutes = now.hour * 60 + now.minute;

    String label;
    var open = false;
    if (today == null || today.isClosed || today.openTime == null || today.closeTime == null) {
      label = context.l10n.closedToday;
    } else {
      final periods = [
        if (today.hasBreak) ...[
          (today.openTime!, today.breakStart!),
          (today.breakEnd!, today.closeTime!),
        ] else
          (today.openTime!, today.closeTime!),
      ];
      final current = periods.where((p) => nowMinutes >= minutes(p.$1) && nowMinutes < minutes(p.$2)).firstOrNull;
      final upcoming = periods.where((p) => nowMinutes < minutes(p.$1)).firstOrNull;
      if (current != null) {
        open = true;
        label = context.l10n.openNowUntil(current.$2.format(context));
      } else if (upcoming != null) {
        label = context.l10n.opensAt(upcoming.$1.format(context));
      } else {
        label = context.l10n.closedNow;
      }
    }
    final color = open ? const Color(0xFF2E7D4F) : AppColors.steel;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(open ? Icons.schedule : Icons.do_not_disturb_on_outlined, size: 16, color: color),
        const SizedBox(width: 4),
        Flexible(child: Text(label, style: TextStyle(color: color, fontWeight: open ? FontWeight.w600 : null))),
      ],
    );
  }
}

class _Services extends ConsumerWidget {
  const _Services({required this.shop, required this.isOwner, required this.brand});

  final PublicBusiness shop;
  final bool isOwner;
  final Color brand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(businessServicesProvider(shop.id));
    final symbol = currencySymbol(shop.currency);
    return services.when(
      loading: () => const SkeletonLines(count: 2),
      error: (error, _) => Text(describeError(context.l10n, error)),
      data: (list) {
        if (list.isEmpty) return Text(context.l10n.noServicesYet);
        return Column(
          children: [
            for (final service in list)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(service.name),
                  subtitle: Text('${service.durationMinutes} min'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$symbol${service.priceInMajorUnits.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      // The owner sees the page as customers do, but can't
                      // book their own shop.
                      if (!isOwner) ...[
                        const SizedBox(width: 12),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: Colors.white),
                          onPressed: () =>
                              context.push('/customer/businesses/${shop.id}/book?serviceId=${service.id}'),
                          child: Text(context.l10n.book),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Barbers extends ConsumerWidget {
  const _Barbers({required this.businessId, required this.brand});

  final String businessId;
  final Color brand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workers = ref.watch(businessWorkersProvider(businessId));
    return workers.when(
      loading: () => const SkeletonLines(count: 2),
      error: (error, _) => Text(describeError(context.l10n, error)),
      data: (list) {
        if (list.isEmpty) return Text(context.l10n.noBarbersYet);
        return Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            for (final worker in list)
              SizedBox(
                width: 72,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: brand.withValues(alpha: 0.15),
                      child: Text(initialsOf(worker.name), style: TextStyle(color: brand, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 4),
                    Text(worker.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Reviews extends ConsumerWidget {
  const _Reviews({required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(businessReviewsProvider(businessId));
    return reviews.when(
      loading: () => const SkeletonLines(count: 2),
      error: (error, _) => Text(describeError(context.l10n, error)),
      data: (list) {
        if (list.isEmpty) return Text(context.l10n.noReviewsYet);
        return Column(children: [for (final review in list) _ReviewTile(review: review)]);
      },
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final ShopReview review;

  @override
  Widget build(BuildContext context) {
    final date = review.createdAt.toLocal();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  Icon(
                    i <= review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 16,
                    color: AppColors.brass,
                  ),
                const SizedBox(width: 8),
                Expanded(child: Text('@${review.username}', overflow: TextOverflow.ellipsis)),
                Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(color: AppColors.steel)),
              ],
            ),
            if (review.comment != null) ...[
              const SizedBox(height: 6),
              Text(review.comment!),
            ],
          ],
        ),
      ),
    );
  }
}

class _Posts extends ConsumerWidget {
  const _Posts({required this.ownerId});

  final String ownerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(postsByAuthorProvider(ownerId));
    final myId = ref.watch(currentProfileProvider).value?.id;
    return posts.when(
      loading: () => const SkeletonLines(count: 2),
      error: (error, _) => Text(describeError(context.l10n, error)),
      data: (list) {
        if (list.isEmpty) return Text(context.l10n.noPostsYet);
        return Column(children: [for (final post in list) PostCard(post: post, isMine: post.authorId == myId)]);
      },
    );
  }
}
