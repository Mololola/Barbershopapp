import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/loading.dart';
import '../../../core/quick_action_tile.dart';
import '../../../core/theme.dart';
import '../../auth/application/auth_controller.dart';
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
    final balance = ref.watch(rewardBalanceProvider).value ?? 0;
    final bookings = ref.watch(myBookingsProvider);
    final conversations = ref.watch(conversationsProvider).value ?? const [];
    final unreadCount = conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
    final pendingInvitations = ref.watch(receivedInvitationsProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barbershop'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/rewards'),
            icon: const Icon(Icons.paid_outlined, color: Colors.white),
            label: Text(
              '\$${(balance / 100).toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/account-settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text('Hey, ${myProfile?.username ?? 'there'}', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text("Here's what's next.", style: TextStyle(color: AppColors.steel)),
          const SizedBox(height: 20),
          bookings.when(
            loading: () => const SizedBox(
              height: 132,
              child: LoadingView(),
            ),
            error: (error, _) => Text('Error: $error'),
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
          Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              QuickActionTile(
                icon: Icons.event_note_outlined,
                label: 'My bookings',
                onTap: () => context.push('/customer/my-bookings'),
              ),
              QuickActionTile(
                icon: Icons.mode_comment_outlined,
                label: 'Messages',
                badgeCount: unreadCount,
                onTap: () => context.push('/messages'),
              ),
              QuickActionTile(
                icon: Icons.emoji_events_outlined,
                label: 'Rankings',
                onTap: () => context.push('/rankings'),
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
                  'NEXT UP',
                  style: TextStyle(
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
                    _relativeLabel(start),
                    style: const TextStyle(color: AppColors.onBrass, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${_weekday(start)}, ${_month(start)} ${start.day}',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: AppColors.chalk, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(_formatTime(start), style: const TextStyle(color: AppColors.chalk, fontSize: 15)),
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
                    business?.name ?? 'Loading…',
                    style: const TextStyle(color: AppColors.chalk, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.brass, padding: EdgeInsets.zero),
                  onPressed: () => context.push('/customer/my-bookings'),
                  child: const Text('View'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _relativeLabel(DateTime start) {
    final now = DateTime.now();
    final days = DateTime(start.year, start.month, start.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return 'In $days days';
  }

  static String _weekday(DateTime d) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];

  static String _month(DateTime d) => const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][d.month - 1];

  static String _formatTime(DateTime d) {
    final time = TimeOfDay.fromDateTime(d);
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
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
                  count == 1
                      ? 'A barbershop wants to hire you — 1 job invitation waiting.'
                      : 'A barbershop wants to hire you — $count job invitations waiting.',
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
            Text('No appointments booked', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Find a shop and get in the chair.', style: TextStyle(color: AppColors.steel)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => context.go('/customer/businesses'),
              child: const Text('Browse barbershops'),
            ),
          ],
        ),
      ),
    );
  }
}
