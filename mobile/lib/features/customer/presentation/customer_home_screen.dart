import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n.dart';
import '../../../core/loading.dart';
import '../../../core/responsive.dart';
import '../../../core/quick_action_tile.dart';
import '../../../core/theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../messaging/presentation/messages_button.dart';
import '../../messaging/application/messaging_controller.dart';
import '../../rewards/application/rewards_controller.dart';
import '../../worker/application/worker_controller.dart';
import '../application/booking_controller.dart';
import '../application/browse_controller.dart';
import '../domain/booking.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myProfile = ref.watch(currentProfileProvider).value;
    final balances = ref.watch(availableBalanceProvider).value ?? const {};
    final bookings = ref.watch(myBookingsProvider);
    final conversations = ref.watch(conversationsProvider).value ?? const [];
    final unreadCount = conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
    final pendingInvitations = ref.watch(receivedInvitationsProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fadra Cut'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/rewards'),
            // White on the phone's dark app bar; the desktop header is light.
            icon: Icon(Icons.paid_outlined, color: isWideLayout(context) ? null : Colors.white),
            label: Text(
              formatBalances(balances),
              style: TextStyle(color: isWideLayout(context) ? null : Colors.white),
            ),
          ),
          const MessagesButton(),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: context.l10n.settingsTitle,
            onPressed: () => context.push('/account-settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(myProfile == null ? context.l10n.greetingNoName : context.l10n.greeting(myProfile.username), style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(context.l10n.whatsNext, style: TextStyle(color: AppColors.steel)),
          const SizedBox(height: 20),
          bookings.when(
            loading: () => const SizedBox(
              height: 132,
              child: LoadingView(),
            ),
            error: (error, _) => Text(context.l10n.errorWithDetail('$error')),
            data: (list) {
              final upcoming = list
                  .where((b) => b.status == BookingStatus.confirmed && b.startTime.isAfter(DateTime.now()))
                  .toList()
                ..sort((a, b) => a.startTime.compareTo(b.startTime));
              return upcoming.isEmpty ? const _NoAppointmentCard() : _NextAppointmentCard(booking: upcoming.first);
            },
          ),
          if (pendingInvitations.isNotEmpty) ...[
            const SizedBox(height: 16),
            _JobInviteBanner(count: pendingInvitations.length),
          ],
          const SizedBox(height: 28),
          Text(context.l10n.quickActions, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              QuickActionTile(
                icon: Icons.event_note_outlined,
                label: context.l10n.myBookings,
                onTap: () => context.push('/customer/my-bookings'),
              ),
              // No DMs for a minor account — see the guardian-consent design.
              if (myProfile?.isMinor != true)
                QuickActionTile(
                  icon: Icons.mode_comment_outlined,
                  label: context.l10n.navMessages,
                  badgeCount: unreadCount,
                  onTap: () => context.push('/messages'),
                ),
              QuickActionTile(
                icon: Icons.emoji_events_outlined,
                label: context.l10n.navRankings,
                onTap: () => context.push('/rankings'),
              ),
              if (myProfile?.isAdmin == true)
                QuickActionTile(
                  icon: Icons.shield_outlined,
                  label: context.l10n.adminEntry,
                  onTap: () => context.push('/admin'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The one deliberate signature element on this screen: a claim-ticket for
/// your next cut, styled like an actual barbershop appointment slip rather
/// than another pale Material card — dark ground, brass perforation, torn
/// off with a "View booking" stub instead of blending into the rest of the
/// page like everything else here does.
class _NextAppointmentCard extends ConsumerWidget {
  const _NextAppointmentCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(businessProvider(booking.businessId)).value;
    final cancelledAt = ref.watch(bookingsAtRiskProvider).value?[booking.id];
    final start = booking.startTime.toLocal();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brass.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.nextUp,
                  style: const TextStyle(
                    color: AppColors.brass,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.brass, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    _relativeLabel(context, start),
                    style: const TextStyle(color: AppColors.onBrass, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              DateFormat.MMMEd(context.l10n.localeName).format(start),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: AppColors.chalk, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(TimeOfDay.fromDateTime(start).format(context), style: const TextStyle(color: AppColors.chalk, fontSize: 15)),
            if (cancelledAt != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.brass),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      shopClosureNotice(context.l10n, cancelledAt, DateTime.now()),
                      style: const TextStyle(color: AppColors.chalk, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            CustomPaint(
              painter: _DashedLinePainter(color: AppColors.brass.withValues(alpha: 0.4)),
              child: const SizedBox(height: 1, width: double.infinity),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.storefront_outlined, size: 16, color: AppColors.chalk),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    business?.name ?? context.l10n.loadingEllipsis,
                    style: const TextStyle(color: AppColors.chalk, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.brass, padding: EdgeInsets.zero),
                  onPressed: () => context.push('/customer/my-bookings'),
                  child: Text(context.l10n.view),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _relativeLabel(BuildContext context, DateTime start) {
    final now = DateTime.now();
    final days = DateTime(start.year, start.month, start.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (days == 0) return context.l10n.today;
    if (days == 1) return context.l10n.tomorrow;
    return context.l10n.inDays(days);
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 5.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) => oldDelegate.color != color;
}

/// So a pending job invitation doesn't sit unnoticed on the worker-profile
/// screen until the customer happens to open it.
class _JobInviteBanner extends StatelessWidget {
  const _JobInviteBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brass.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/customer/worker-profile'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.work_outline, color: AppColors.brass),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.jobInvitations(count),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.brass),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoAppointmentCard extends StatelessWidget {
  const _NoAppointmentCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.content_cut, color: AppColors.brass, size: 28),
            const SizedBox(height: 10),
            Text(context.l10n.noAppointments, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(context.l10n.noAppointmentsHint, style: const TextStyle(color: AppColors.steel)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => context.go('/customer/businesses'),
              child: Text(context.l10n.browseBarbershops),
            ),
          ],
        ),
      ),
    );
  }
}
