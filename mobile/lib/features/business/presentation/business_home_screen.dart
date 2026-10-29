import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/app_network_image.dart';
import '../../../core/l10n.dart';
import '../../../core/responsive.dart';
import '../../../core/skeleton.dart';
import '../../../core/theme.dart';
import '../../messaging/presentation/messages_button.dart';
import '../application/business_controller.dart';
import '../domain/business.dart';
import '../domain/today_summary.dart';
import 'subscription_banner.dart';

class BusinessHomeScreen extends ConsumerWidget {
  const BusinessHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(currentBusinessProvider);
    final locations = ref.watch(locationsProvider);
    final hours = ref.watch(openingHoursProvider);
    final services = ref.watch(servicesProvider);
    final workers = ref.watch(workersProvider);
    final bookings = ref.watch(businessBookingsProvider);

    // On a wide screen the sidebar carries the brand, Messages and Settings.
    final wide = isWideLayout(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(wide ? context.l10n.navHome : context.l10n.fadraForBusiness),
        actions: [
          if (wide)
            // Pull-to-refresh needs a touch screen.
            IconButton(
              tooltip: context.l10n.refresh,
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(businessBookingsProvider),
            )
          else ...[
            const MessagesButton(),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: context.l10n.settingsTitle,
              onPressed: () => context.push('/account-settings'),
            ),
          ],
        ],
      ),
      body: business.when(
        loading: () => const SkeletonList(count: 4),
        error: (error, _) => Center(child: Text(describeError(context.l10n, error))),
        data: (business) {
          if (business == null) {
            return Center(child: Text(context.l10n.noBusinessFound));
          }
          final today = bookings.hasValue
              ? _TodayCard(
                  summary: summarizeToday(bookings.value!, DateTime.now()),
                  workerNames: {
                    for (final w in workers.value ?? const <Worker>[])
                      if (w.id != null) w.id!: w.name,
                  },
                  serviceNames: {
                    for (final s in services.value ?? const <Service>[])
                      if (s.id != null) s.id!: s.name,
                  },
                )
              : null;
          final stats = Row(
            children: [
              Expanded(
                child: _StatChip(
                  value: services.value?.length,
                  label: context.l10n.serviceCountLabel(services.value?.length ?? 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatChip(
                  value: workers.value?.length,
                  label: context.l10n.staffCountLabel(workers.value?.length ?? 0),
                ),
              ),
            ],
          );
          final hoursSection = _Section(
            header: _SectionHeader(title: context.l10n.thisWeek, onManage: () => context.push('/business/edit')),
            child: hours.when(
              loading: () => const SkeletonLines(),
              error: (error, _) => Text(describeError(context.l10n, error)),
              data: (list) => _HoursCard(hours: list),
            ),
          );
          final servicesSection = _Section(
            header: _SectionHeader(title: context.l10n.services, onManage: () => context.push('/business/services')),
            child: services.when(
              loading: () => const SkeletonLines(),
              error: (error, _) => Text(describeError(context.l10n, error)),
              data: (list) {
                if (list.isEmpty) {
                  return Text(context.l10n.noServicesYet, style: const TextStyle(color: AppColors.steel));
                }
                return Card(
                  child: Column(
                    children: [
                      for (final service in list)
                        ListTile(
                          leading: const Icon(Icons.content_cut, color: AppColors.brass),
                          title: Text(service.name),
                          trailing: Text(
                            '${currencySymbol(business.currency)}${service.priceInMajorUnits.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
          final staffSection = _Section(
            header: _SectionHeader(title: context.l10n.navStaff, onManage: () => context.go('/business/staff')),
            child: workers.when(
              loading: () => const SkeletonLines(),
              error: (error, _) => Text(describeError(context.l10n, error)),
              data: (list) {
                if (list.isEmpty) {
                  return Text(context.l10n.noStaffYet, style: const TextStyle(color: AppColors.steel));
                }
                return Card(
                  child: Column(
                    children: [
                      for (final worker in list)
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.chalk,
                            child: Icon(Icons.person_outline, color: AppColors.brass),
                          ),
                          title: Text(worker.name),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
          final plaque = _ShopPlaque(business: business, locations: locations, hours: hours);

          return RefreshIndicator(
            // New bookings arrive from customers at any time; pull to catch up.
            onRefresh: () => ref.refresh(businessBookingsProvider.future),
            child: wide
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                    children: [
                      const SubscriptionBanner(),
                      ResponsiveColumns(
                        flex: const [3, 2],
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [plaque, const SizedBox(height: 16), ?today, const SizedBox(height: 16), stats],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [const _FinanceCard(), const SizedBox(height: 16), hoursSection],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ResponsiveColumns(children: [servicesSection, staffSection]),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const SubscriptionBanner(),
                      plaque,
                      const SizedBox(height: 16),
                      ?today,
                      const SizedBox(height: 12),
                      const _FinanceCard(),
                      const SizedBox(height: 16),
                      stats,
                      const SizedBox(height: 24),
                      hoursSection,
                      const SizedBox(height: 24),
                      servicesSection,
                      const SizedBox(height: 24),
                      staffSection,
                    ],
                  ),
          );
        },
      ),
    );
  }
}

/// The shop's own storefront sign — same dark-ground, brass-accented
/// treatment as the customer home's appointment ticket, so the two
/// dashboards read as one identity, but built around what a shop owner
/// actually wants at a glance: is the shop open right now, and where is it.
class _ShopPlaque extends StatelessWidget {
  const _ShopPlaque({required this.business, required this.locations, required this.hours});

  final Business business;
  final AsyncValue<List<BusinessLocation>> locations;
  final AsyncValue<List<OpeningHours>> hours;

  @override
  Widget build(BuildContext context) {
    final address = locations.value?.firstOrNull;
    final openNow = _isOpenNow(hours.value);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brass.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipOval(
              child: SizedBox(
                width: 56,
                height: 56,
                child: business.logoUrl != null
                    ? AppNetworkImage(business.logoUrl!)
                    : ColoredBox(
                        color: AppColors.brass.withValues(alpha: 0.2),
                        child: const Icon(Icons.storefront, color: AppColors.brass, size: 28),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.name,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: AppColors.chalk, fontWeight: FontWeight.w800),
                  ),
                  if (address != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      address.displayAddress,
                      style: const TextStyle(color: AppColors.chalk, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (openNow != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: openNow ? AppColors.brass : AppColors.steel,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        openNow ? context.l10n.openNowBadge : context.l10n.closedNowBadge,
                        style: const TextStyle(color: AppColors.onBrass, fontWeight: FontWeight.w700, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool? _isOpenNow(List<OpeningHours>? list) {
    if (list == null || list.isEmpty) return null;
    final now = DateTime.now();
    final today = list.where((h) => h.dayOfWeek == now.weekday - 1).firstOrNull;
    if (today == null || today.isClosed || today.openTime == null || today.closeTime == null) return false;
    final minutesNow = now.hour * 60 + now.minute;
    final openMinutes = today.openTime!.hour * 60 + today.openTime!.minute;
    final closeMinutes = today.closeTime!.hour * 60 + today.closeTime!.minute;
    return minutesNow >= openMinutes && minutesNow < closeMinutes;
  }
}

/// "in 25 min" / "in 3 h" today, "Tomorrow", otherwise "Thu, Oct 2".
String _whenLabel(BuildContext context, DateTime start, DateTime now) {
  final local = start.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final daysAway = day.difference(today).inDays;
  if (daysAway == 0) {
    final minutes = local.difference(now).inMinutes;
    return minutes < 60 ? context.l10n.inMinutes(minutes) : context.l10n.inHours(minutes ~/ 60);
  }
  if (daysAway == 1) return context.l10n.tomorrow;
  return DateFormat.MMMEd(context.l10n.localeName).format(local);
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.summary, required this.workerNames, required this.serviceNames});

  final TodaySummary summary;
  final Map<String, String> workerNames;
  final Map<String, String> serviceNames;

  // A booking can outlive its barber's time on the staff list (history is
  // kept), so a missing name isn't an error.
  String _worker(BuildContext context, String id) => workerNames[id] ?? context.l10n.formerStaff;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final next = summary.next;
    final now = DateTime.now();
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.go('/business/bookings'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${summary.bookingsToday}',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.brass),
                ),
                const SizedBox(width: 8),
                Text(context.l10n.bookingsTodayLabel(summary.bookingsToday), style: textTheme.titleMedium),
              ],
            ),
            if (summary.perWorker.isNotEmpty)
              Text(
                summary.perWorker.map((e) => '${_worker(context, e.key)} ${e.value}').join(' · '),
                style: const TextStyle(color: AppColors.steel),
              ),
            const Divider(height: 24),
            Text(context.l10n.nextBooking, style: textTheme.labelMedium?.copyWith(color: AppColors.steel)),
            const SizedBox(height: 2),
            if (next == null)
              Text(context.l10n.nothingBookedYet)
            else ...[
              // Wrap, not Row: "10:15 PM" + "Thu 2 Oct" overflows a phone at
              // larger text sizes.
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    TimeOfDay.fromDateTime(next.startTime.toLocal()).format(context),
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(_whenLabel(context, next.startTime, now), style: const TextStyle(color: AppColors.steel)),
                ],
              ),
              Text(
                context.l10n.withBarber(_worker(context, next.workerId)) +
                    (serviceNames[next.serviceId] == null ? '' : ' · ${serviceNames[next.serviceId]}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The finance tool used to be a bottom tab; it's used monthly rather than
/// daily, so it lives here and the tab went to the feed.
class _FinanceCard extends StatelessWidget {
  const _FinanceCard();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/business/finance'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.payments_outlined, color: AppColors.brass),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.navFinance, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(context.l10n.financeTileSubtitle, style: const TextStyle(color: AppColors.steel)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.steel),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.value, required this.label});

  final int? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Text(
            value?.toString() ?? '–',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.brass),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.steel, fontSize: 13))),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onManage});

  final String title;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          TextButton(onPressed: onManage, child: Text(context.l10n.manage)),
        ],
      ),
    );
  }
}

/// A section header with its content, kept together so a wide layout can
/// place them as one block.
class _Section extends StatelessWidget {
  const _Section({required this.header, required this.child});

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, child]);
  }
}

class _HoursCard extends StatelessWidget {
  const _HoursCard({required this.hours});

  final List<OpeningHours> hours;

  @override
  Widget build(BuildContext context) {
    final sorted = [...hours]..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
    final today = DateTime.now().weekday - 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (final h in sorted)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        context.weekdayName(h.dayOfWeek),
                        style: TextStyle(
                          fontWeight: h.dayOfWeek == today ? FontWeight.w700 : FontWeight.w400,
                          color: h.dayOfWeek == today ? AppColors.brass : null,
                        ),
                      ),
                    ),
                    Text(
                      h.format(context),
                      style: TextStyle(
                        fontWeight: h.dayOfWeek == today ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
