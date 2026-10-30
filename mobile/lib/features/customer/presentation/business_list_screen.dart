import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/app_network_image.dart';
import '../../../core/device_location.dart';
import '../../../core/l10n.dart';
import '../../../core/responsive.dart';
import '../../../core/skeleton.dart';
import '../../../core/theme.dart';
import '../../business/domain/finance_overview.dart';
import '../application/browse_controller.dart';
import '../domain/shop_listing.dart';

class BusinessListScreen extends ConsumerStatefulWidget {
  const BusinessListScreen({super.key});

  @override
  ConsumerState<BusinessListScreen> createState() => _BusinessListScreenState();
}

class _BusinessListScreenState extends ConsumerState<BusinessListScreen> {
  final _queryController = TextEditingController();
  String _query = '';

  /// Set while "Near me" is on; the list is then sorted by distance.
  LatLng? _nearMe;
  bool _locating = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _toggleNearMe() async {
    if (_nearMe != null) {
      setState(() => _nearMe = null);
      return;
    }
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final location = ref.read(deviceLocationProvider);
    setState(() => _locating = true);
    final result = await location.current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _nearMe = result.position;
    });
    final (message, action) = switch (result.problem) {
      null => (null, null),
      LocationProblem.serviceOff => (l10n.locationServiceOff, location.openLocationSettings),
      LocationProblem.denied => (l10n.locationDenied, null),
      LocationProblem.deniedForever => (l10n.locationDeniedForever, location.openAppSettings),
      LocationProblem.failed => (l10n.locationFailed, null),
    };
    if (message == null) return;
    messenger.showSnackBar(SnackBar(
      content: Text(message),
      action: action == null ? null : SnackBarAction(label: l10n.settingsTitle, onPressed: action),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(shopListingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.findAShop)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: TextField(
                controller: _queryController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: context.l10n.searchByNameOrCity,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _queryController.clear();
                            _query = '';
                          }),
                        ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: FilterChip(
              avatar: _locating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.near_me_outlined, size: 18),
              label: Text(context.l10n.nearMe),
              selected: _nearMe != null,
              showCheckmark: false,
              onSelected: _locating ? null : (_) => _toggleNearMe(),
            ),
          ),
          Expanded(
            child: listings.when(
              loading: () => const SkeletonList(leading: SkeletonLeading.square),
              error: (error, _) => Center(child: Text(describeError(context.l10n, error))),
              data: (list) {
                if (list.isEmpty) {
                  return _EmptyState(
                    icon: Icons.storefront_outlined,
                    title: context.l10n.noBarbershopsYet,
                    subtitle: context.l10n.noBarbershopsHint,
                  );
                }
                final nearMe = _nearMe;
                final filtered = _query.trim().isEmpty ? list : list.where((shop) => shop.matches(_query)).toList();
                if (filtered.isEmpty) {
                  return _EmptyState(
                    icon: Icons.search_off,
                    title: context.l10n.noMatchesFor(_query),
                    subtitle: context.l10n.tryNameCityOrNearMe,
                  );
                }
                final distances = {
                  if (nearMe != null)
                    for (final shop in filtered) shop.business.id: shop.nearestFrom(nearMe),
                };
                // Shops not located yet go last, still in name order.
                final shown = nearMe == null
                    ? filtered
                    : ([...filtered]..sort((a, b) {
                        final da = distances[a.business.id]?.km ?? double.infinity;
                        final db = distances[b.business.id]?.km ?? double.infinity;
                        return da.compareTo(db);
                      }));
                if (isWideLayout(context)) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      TileGrid(
                        minTileWidth: 340,
                        children: [
                          for (final shop in shown) _ShopCard(shop: shop, distance: distances[shop.business.id]),
                        ],
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  itemCount: shown.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _ShopCard(shop: shown[index], distance: distances[shown[index].business.id]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.shop, this.distance});

  final ShopListing shop;
  final ({double km, String country})? distance;

  /// Miles in the UK, kilometres in Spain, as people there expect.
  String _distanceLabel(BuildContext context, ({double km, String country}) distance) {
    final number = NumberFormat('#,##0.0', context.l10n.localeName);
    return distance.country == 'GB'
        ? context.l10n.distanceMiles(number.format(distance.km / 1.609344))
        : context.l10n.distanceKm(number.format(distance.km));
  }

  @override
  Widget build(BuildContext context) {
    final business = shop.business;
    final rating = business.averageRating;
    final cities = shop.cities;
    final details = [
      rating == null || business.reviewCount == 0
          ? context.l10n.newShop
          : '★ ${NumberFormat('0.0', context.l10n.localeName).format(rating)} (${business.reviewCount})',
      if (cities.isNotEmpty) cities.length == 1 ? cities.first : '${cities.first} +${cities.length - 1}',
    ].join(' · ');

    return Material(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/customer/businesses/${business.id}'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: business.logoUrl != null
                      ? AppNetworkImage(business.logoUrl!)
                      : ColoredBox(
                          color: AppColors.brass.withValues(alpha: 0.15),
                          child: const Icon(Icons.content_cut, color: AppColors.brass),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(details, style: const TextStyle(color: AppColors.steel), overflow: TextOverflow.ellipsis),
                    if (shop.fromPriceCents != null)
                      Text(context.l10n.fromPrice(formatMoney(shop.fromPriceCents!, business.currency))),
                  ],
                ),
              ),
              if (distance != null) ...[
                const SizedBox(width: 8),
                Text(_distanceLabel(context, distance!), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
              const Icon(Icons.chevron_right, color: AppColors.steel),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.brass, size: 40),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.steel)),
          ],
        ),
      ),
    );
  }
}
