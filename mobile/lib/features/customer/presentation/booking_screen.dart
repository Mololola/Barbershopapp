import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/loading.dart';
import '../../../core/status_message.dart';
import '../../business/domain/brand.dart';
import '../../business/domain/finance_overview.dart';
import '../application/booking_controller.dart';
import '../application/browse_controller.dart';
import '../domain/booking.dart';

const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// How far ahead a customer can book.
const _bookingWindowDays = 60;

String _dayLabel(DateTime day) => '${_weekdayShort[day.weekday - 1]} ${day.day} ${_monthShort[day.month - 1]}';

String _timeLabel(BuildContext context, DateTime time) => TimeOfDay.fromDateTime(time.toLocal()).format(context);

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.businessId, required this.serviceId});

  final String businessId;
  final String serviceId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final DateTime _today = DateUtils.dateOnly(DateTime.now());
  late DateTime _date = _today;
  AvailableSlot? _selectedSlot;

  /// Null means "any barber".
  String? _barberId;

  final _dayStrip = ScrollController();

  @override
  void dispose() {
    _dayStrip.dispose();
    super.dispose();
  }

  void _selectDate(DateTime day) {
    setState(() {
      _date = day;
      _selectedSlot = null;
      _barberId = null;
    });
  }

  /// Selects [day] and scrolls the strip to it — for days that may be
  /// off-screen (picked from the calendar, or suggested when one is full).
  void _jumpToDate(DateTime day) {
    _selectDate(day);
    final offset = ((day.difference(_today).inHours / 24).round() * (_DayTile.width + _DayTile.gap))
        .clamp(0.0, _dayStrip.position.maxScrollExtent);
    _dayStrip.animateTo(offset, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: _bookingWindowDays)),
    );
    if (picked != null) _jumpToDate(picked);
  }

  Future<void> _confirm() async {
    final slot = _selectedSlot;
    if (slot == null) return;

    final booking = await ref.read(bookingActionControllerProvider.notifier).createBooking(
          businessId: widget.businessId,
          workerId: slot.workerId,
          serviceId: widget.serviceId,
          startTime: slot.startTime,
        );

    if (!mounted) return;
    if (booking != null) {
      // Clear the browse/booking flow off the stack first so "back" from My
      // Bookings goes straight to Customer home, not back through booking.
      context.go('/customer');
      context.push('/customer/my-bookings');
    } else {
      // On conflict (slot just taken), refresh availability so the stale slot disappears.
      ref.invalidate(
        availabilityProvider((businessId: widget.businessId, serviceId: widget.serviceId, date: _date)),
      );
      setState(() => _selectedSlot = null);
    }
  }

  AvailabilityQuery get _query => (businessId: widget.businessId, serviceId: widget.serviceId, date: _date);

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingActionControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Book appointment')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _ServiceSummary(businessId: widget.businessId, serviceId: widget.serviceId),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Day',
            trailing: TextButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: const Text('Calendar'),
            ),
          ),
          SizedBox(
            height: _DayTile.height,
            child: ListView.separated(
              controller: _dayStrip,
              scrollDirection: Axis.horizontal,
              itemCount: _bookingWindowDays + 1,
              separatorBuilder: (_, _) => const SizedBox(width: _DayTile.gap),
              itemBuilder: (context, i) {
                final day = DateTime(_today.year, _today.month, _today.day + i);
                return _DayTile(
                  day: day,
                  isToday: i == 0,
                  selected: DateUtils.isSameDay(day, _date),
                  onTap: () => _selectDate(day),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _buildAvailability(context),
        ],
      ),
      // In the thumb zone, and always in view: what's chosen so far and the
      // one action left.
      bottomNavigationBar: Material(
        color: theme.colorScheme.surface,
        shape: Border(top: BorderSide(color: theme.colorScheme.outline)),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (bookingState.hasError) ...[
                  Text(
                    bookingState.error.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _selectedSlot == null
                          ? Text(
                              'Pick a time to continue',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_dayLabel(_date)} · ${_timeLabel(context, _selectedSlot!.startTime)}',
                                  style: theme.textTheme.titleLarge,
                                ),
                                Text(
                                  'with ${_selectedSlot!.workerName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton(
                      onPressed: (_selectedSlot == null || bookingState.isLoading) ? null : _confirm,
                      child: bookingState.isLoading
                          ? SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary),
                            )
                          : const Text('Book'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailability(BuildContext context) {
    final availability = ref.watch(availabilityProvider(_query));
    return availability.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: LoadingView(caption: 'Finding free times…'),
      ),
      error: (_, _) => StatusMessage(
        icon: Icons.wifi_off_rounded,
        title: 'Couldn\'t load times',
        message: 'Check your connection and try again.',
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(availabilityProvider(_query)),
        isError: true,
      ),
      data: (slots) {
        if (slots.isEmpty) {
          final nextDay = DateTime(_date.year, _date.month, _date.day + 1);
          final canTryNext = !nextDay.isAfter(_today.add(const Duration(days: _bookingWindowDays)));
          return StatusMessage(
            icon: Icons.event_busy_outlined,
            title: 'No free times on ${_dayLabel(_date)}',
            message: 'The shop is closed or fully booked that day.',
            actionLabel: canTryNext ? 'Try ${_dayLabel(nextDay)}' : null,
            onAction: canTryNext ? () => _jumpToDate(nextDay) : null,
          );
        }
        // Times come every 15 minutes per barber, so choosing the barber
        // first keeps the list short. Slots arrive sorted by time, then
        // barber name.
        final barbers = <String, String>{for (final slot in slots) slot.workerId: slot.workerName};
        final times = <DateTime>{};
        final shown = _barberId == null
            // "Any barber": one tile per time, booked with the first barber free then.
            ? slots.where((slot) => times.add(slot.startTime)).toList()
            : slots.where((slot) => slot.workerId == _barberId).toList();
        final periods = <String, List<AvailableSlot>>{};
        for (final slot in shown) {
          final hour = slot.startTime.toLocal().hour;
          final period = hour < 12 ? 'Morning' : (hour < 17 ? 'Afternoon' : 'Evening');
          periods.putIfAbsent(period, () => []).add(slot);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader(title: 'Barber'),
            SizedBox(
              height: _BarberChoice.height,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _BarberChoice(
                    name: null,
                    selected: _barberId == null,
                    onTap: () => setState(() {
                      _barberId = null;
                      _selectedSlot = null;
                    }),
                  ),
                  for (final entry in barbers.entries)
                    _BarberChoice(
                      name: entry.value,
                      selected: _barberId == entry.key,
                      onTap: () => setState(() {
                        _barberId = entry.key;
                        _selectedSlot = null;
                      }),
                    ),
                ],
              ),
            ),
            for (final period in periods.entries) ...[
              const SizedBox(height: 24),
              _SectionHeader(title: period.key, count: '${period.value.length} free'),
              _TimeGrid(
                slots: period.value,
                selected: _selectedSlot,
                onSelected: (slot) => setState(() => _selectedSlot = slot),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// What's being booked, so the customer never has to go back to check.
class _ServiceSummary extends ConsumerWidget {
  const _ServiceSummary({required this.businessId, required this.serviceId});

  final String businessId;
  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(businessProvider(businessId)).value;
    final service = ref.watch(businessServicesProvider(businessId)).value?.where((s) => s.id == serviceId).firstOrNull;
    if (shop == null || service == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurface.withValues(alpha: 0.65);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: brandColorOf(businessId: shop.id, storedHex: shop.brandColor),
              foregroundColor: Colors.white,
              backgroundImage: shop.logoUrl != null ? NetworkImage(shop.logoUrl!) : null,
              child: shop.logoUrl == null ? Text(initialsOf(shop.name)) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.name, style: theme.textTheme.titleLarge),
                  Text(
                    '${shop.name} · ${service.durationMinutes} min',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatMoney(service.priceCents, shop.currency),
              style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.count, this.trailing});

  final String title;
  final String? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text(
              count!,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
            ),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// The theme's card shape outlined in [side], so every tile keeps the
/// app's own corner radius.
ShapeBorder _tileShape(ThemeData theme, BorderSide side) {
  final shape = theme.cardTheme.shape;
  return shape is OutlinedBorder ? shape.copyWith(side: side) : RoundedRectangleBorder(side: side);
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day, required this.isToday, required this.selected, required this.onTap});

  static const width = 56.0;
  static const height = 76.0;
  static const gap = 8.0;

  final DateTime day;
  final bool isToday;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected ? scheme.onPrimary : scheme.onSurface;
    final small = theme.textTheme.labelSmall?.copyWith(color: foreground.withValues(alpha: 0.7));
    return SizedBox(
      width: width,
      child: Material(
        color: selected ? scheme.primary : scheme.surface,
        shape: _tileShape(theme, BorderSide(color: selected ? scheme.primary : scheme.outline)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(isToday ? 'Today' : _weekdayShort[day.weekday - 1], style: small),
              Text('${day.day}', style: theme.textTheme.headlineSmall?.copyWith(color: foreground, height: 1.1)),
              Text(_monthShort[day.month - 1], style: small),
            ],
          ),
        ),
      ),
    );
  }
}

/// A barber as an initials avatar; a null [name] is "any barber".
class _BarberChoice extends StatelessWidget {
  const _BarberChoice({required this.name, required this.selected, required this.onTap});

  static const height = 88.0;

  final String? name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      width: 76,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(height / 2),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 2),
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: selected ? scheme.primary : scheme.primary.withValues(alpha: 0.12),
                foregroundColor: selected ? scheme.onPrimary : scheme.primary,
                child: name == null ? const Icon(Icons.groups_outlined) : Text(initialsOf(name!)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name == null ? 'Any barber' : name!.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: selected ? FontWeight.w600 : null,
                color: scheme.onSurface.withValues(alpha: selected ? 1 : 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Times in even columns, so they read as a timetable rather than a ragged
/// row of chips.
class _TimeGrid extends StatelessWidget {
  const _TimeGrid({required this.slots, required this.selected, required this.onSelected});

  final List<AvailableSlot> slots;
  final AvailableSlot? selected;
  final ValueChanged<AvailableSlot> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.75,
      children: [
        for (final slot in slots)
          Material(
            color: slot == selected ? scheme.primary : scheme.surface,
            shape: _tileShape(theme, BorderSide(color: slot == selected ? scheme.primary : scheme.outline)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelected(slot),
              child: Center(
                child: Text(
                  _timeLabel(context, slot.startTime),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: slot == selected ? scheme.onPrimary : scheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
