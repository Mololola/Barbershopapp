import 'package:flutter/material.dart';

import '../../../core/l10n.dart';
import '../domain/business.dart';

/// Default break offered by "Add break" — adjustable once added.
const _defaultBreakStart = TimeOfDay(hour: 13, minute: 0);
const _defaultBreakEnd = TimeOfDay(hour: 14, minute: 0);

/// The editable week of a shop's opening hours or a worker's schedule: per
/// day open/closed, opening and closing time, and an optional break. The
/// caller owns [hours] (7 entries, Monday first); [onChanged] reports each
/// edited day for the caller to store and setState.
class OpeningHoursEditor extends StatelessWidget {
  const OpeningHoursEditor({
    super.key,
    required this.hours,
    required this.onChanged,
    this.closedLabel,
  });

  final List<OpeningHours> hours;
  final void Function(int dayIndex, OpeningHours day) onChanged;

  /// Shown on a day that's off; "Closed" when not given.
  final String? closedLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < hours.length; i++)
          _DayEditor(day: hours[i], closedLabel: closedLabel ?? context.l10n.closed, onChanged: (day) => onChanged(i, day)),
      ],
    );
  }
}

class _DayEditor extends StatelessWidget {
  const _DayEditor({required this.day, required this.closedLabel, required this.onChanged});

  final OpeningHours day;
  final String closedLabel;
  final ValueChanged<OpeningHours> onChanged;

  Future<TimeOfDay?> _pick(BuildContext context, TimeOfDay? current) {
    return showTimePicker(context: context, initialTime: current ?? TimeOfDay.now());
  }

  Widget _timeButton(BuildContext context, TimeOfDay? value, String placeholder, ValueChanged<TimeOfDay> onPicked) {
    return TextButton(
      onPressed: () async {
        final picked = await _pick(context, value);
        if (picked != null) onPicked(picked);
      },
      child: Text(value?.format(context) ?? placeholder),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Expanded(child: Text(context.weekdayName(day.dayOfWeek))),
              if (day.isClosed) Text(closedLabel),
              Switch(value: !day.isClosed, onChanged: (open) => onChanged(day.copyWith(isClosed: !open))),
            ],
          ),
          // Times sit on their own lines rather than beside the day name, and
          // wrap rather than overflow a phone screen at larger text sizes.
          if (!day.isClosed) ...[
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _timeButton(context, day.openTime, context.l10n.start, (t) => onChanged(day.copyWith(openTime: t))),
                const Text('–'),
                _timeButton(context, day.closeTime, context.l10n.end, (t) => onChanged(day.copyWith(closeTime: t))),
              ],
            ),
            if (day.hasBreak)
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(context.l10n.breakLabel),
                  _timeButton(context, day.breakStart, context.l10n.start, (t) => onChanged(day.withBreak(t, day.breakEnd))),
                  const Text('–'),
                  _timeButton(context, day.breakEnd, context.l10n.end, (t) => onChanged(day.withBreak(day.breakStart, t))),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: context.l10n.removeBreak,
                    onPressed: () => onChanged(day.withBreak(null, null)),
                  ),
                ],
              )
            else
              TextButton.icon(
                onPressed: () => onChanged(day.withBreak(_defaultBreakStart, _defaultBreakEnd)),
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.l10n.addBreak),
              ),
            if (!day.hasValidRange)
              Text(
                context.l10n.hoursRangeError,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                textAlign: TextAlign.end,
              ),
          ],
        ],
      ),
    );
  }
}
