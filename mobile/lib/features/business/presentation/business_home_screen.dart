import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_network_image.dart';
import '../../../core/loading.dart';
import '../../../core/quick_action_tile.dart';
import '../../../core/theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../messaging/application/messaging_controller.dart';
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
    final myProfile = ref.watch(currentProfileProvider).value;
    final conversations = ref.watch(conversationsProvider).value ?? const [];
    final unreadCount = conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barbershop for Business'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/account-settings'),
          ),
        ],
      ),
      body: business.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (business) {
          if (business == null) {
            return const Center(child: Text('No business found.'));
          }
          return RefreshIndicator(
            // New bookings arrive from customers at any time; pull to catch up.
            onRefresh: () => ref.refresh(businessBookingsProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SubscriptionBanner(),
                _ShopPlaque(business: business, locations: locations, hours: hours),
                const SizedBox(height: 16),
                if (bookings.hasValue)
                  _TodayCard(
                    summary: summarizeToday(bookings.value!, DateTime.now()),
                    workerNames: {
                      for (final w in workers.value ?? const <Worker>[])
                        if (w.id != null) w.id!: w.name,
                    },
                    serviceNames: {
                      for (final s in services.value ?? const <Service>[])
                        if (s.id != null) s.id!: s.name,
                    },
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatChip(
                        value: services.value?.length,
                        label: services.value?.length == 1 ? 'service' : 'services',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatChip(
                        value: workers.value?.length,
                        label: workers.value?.length == 1 ? 'staff member' : 'staff',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionHeader(title: 'This week', onManage: () => context.push('/business/edit')),
                hours.when(
                  loading: () => const LoadingView(),
                  error: (error, _) => Text('Error: $error'),
                  data: (list) => _HoursCard(hours: list),
                ),
                const SizedBox(height: 24),
                _SectionHeader(title: 'Services', onManage: () => context.push('/business/services')),
                services.when(
                  loading: () => const LoadingView(),
                  error: (error, _) => Text('Error: $error'),
                  data: (list) {
                    if (list.isEmpty) {
                      return const Text('No services listed yet.', style: TextStyle(color: AppColors.steel));
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
                const SizedBox(height: 24),
                _SectionHeader(title: 'Staff', onManage: () => context.push('/business/staff')),
                workers.when(
                  loading: () => const LoadingView(),
                  error: (error, _) => Text('Error: $error'),
                  data: (list) {
                    if (list.isEmpty) {
                      return const Text('No staff yet.', style: TextStyle(color: AppColors.steel));
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
                const SizedBox(height: 28),
                Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    QuickActionTile(
                      icon: Icons.photo_outlined,
                      label: 'Feed',
                      onTap: () => context.push('/feed'),
                    ),
                    QuickActionTile(
                      icon: Icons.mode_comment_outlined,
                      label: 'Messages',
                      badgeCount: unreadCount,
                      onTap: () => context.push('/messages'),
                    ),
                    if (myProfile?.isAdmin == true)
                      QuickActionTile(
                        icon: Icons.shield_outlined,
                        label: 'Admin',
                        onTap: () => context.push('/admin'),
                      ),
                  ],
                ),
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
                        openNow ? 'OPEN NOW' : 'CLOSED NOW',
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

const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "in 25 min" / "in 3 h" today, "Tomorrow", otherwise "Thu 2 Oct".
String _whenLabel(DateTime start, DateTime now) {
  final local = start.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final daysAway = day.difference(today).inDays;
  if (daysAway == 0) {
    final minutes = local.difference(now).inMinutes;
    return minutes < 60 ? 'in $minutes min' : 'in ${minutes ~/ 60} h';
  }
  if (daysAway == 1) return 'Tomorrow';
  return '${_weekdayShort[local.weekday - 1]} ${local.day} ${_monthShort[local.month - 1]}';
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.summary, required this.workerNames, required this.serviceNames});

  final TodaySummary summary;
  final Map<String, String> workerNames;
  final Map<String, String> serviceNames;

  // A booking can outlive its barber's time on the staff list (history is
  // kept), so a missing name isn't an error.
  String _worker(String id) => workerNames[id] ?? 'Former staff';

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
                Text(summary.bookingsToday == 1 ? 'booking today' : 'bookings today', style: textTheme.titleMedium),
              ],
            ),
            if (summary.perWorker.isNotEmpty)
              Text(
                summary.perWorker.map((e) => '${_worker(e.key)} ${e.value}').join(' · '),
                style: const TextStyle(color: AppColors.steel),
              ),
            const Divider(height: 24),
            Text('Next booking', style: textTheme.labelMedium?.copyWith(color: AppColors.steel)),
            const SizedBox(height: 2),
            if (next == null)
              const Text('Nothing booked yet')
            else ...[
              Row(
                children: [
                  Text(
                    TimeOfDay.fromDateTime(next.startTime.toLocal()).format(context),
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Text(_whenLabel(next.startTime, now), style: const TextStyle(color: AppColors.steel)),
                ],
              ),
              Text(
                'with ${_worker(next.workerId)}'
                '${serviceNames[next.serviceId] == null ? '' : ' · ${serviceNames[next.serviceId]}'}',
              ),
            ],
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
          TextButton(onPressed: onManage, child: const Text('Manage')),
        ],
      ),
    );
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
                        OpeningHours.dayNames[h.dayOfWeek],
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
