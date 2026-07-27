import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/business_controller.dart';
import '../domain/business.dart';

class WorkerScheduleScreen extends ConsumerStatefulWidget {
  const WorkerScheduleScreen({super.key, required this.workerId, required this.workerName});

  final String workerId;
  final String workerName;

  @override
  ConsumerState<WorkerScheduleScreen> createState() => _WorkerScheduleScreenState();
}

class _WorkerScheduleScreenState extends ConsumerState<WorkerScheduleScreen> {
  List<OpeningHours>? _hours;

  void _seedIfNeeded(List<OpeningHours> existing) {
    if (_hours != null) return;
    if (existing.isEmpty) {
      _hours = OpeningHours.defaultWeek();
      return;
    }
    final byDay = {for (final h in existing) h.dayOfWeek: h};
    _hours = [for (var day = 0; day < 7; day++) byDay[day] ?? OpeningHours(dayOfWeek: day, isClosed: true)];
  }

  Future<void> _pickTime(int dayIndex, {required bool isOpenTime}) async {
    final current = isOpenTime ? _hours![dayIndex].openTime : _hours![dayIndex].closeTime;
    final picked = await showTimePicker(context: context, initialTime: current ?? TimeOfDay.now());
    if (picked == null) return;
    setState(() {
      _hours![dayIndex] = isOpenTime
          ? _hours![dayIndex].copyWith(openTime: picked)
          : _hours![dayIndex].copyWith(closeTime: picked);
    });
  }

  Future<void> _save() async {
    final hours = _hours;
    if (hours == null) return;
    await ref.read(workerScheduleControllerProvider.notifier).save(widget.workerId, hours);
  }

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(workerScheduleProvider(widget.workerId));
    final saveState = ref.watch(workerScheduleControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text('${widget.workerName}\'s schedule')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: schedule.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
          data: (existing) {
            _seedIfNeeded(existing);
            final hours = _hours!;

            return ListView(
              children: [
                Text(
                  'Days left off use the shop\'s own opening hours instead.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < hours.length; i++)
                  Row(
                    children: [
                      SizedBox(width: 100, child: Text(OpeningHours.dayNames[i])),
                      Switch(
                        value: !hours[i].isClosed,
                        onChanged: (open) => setState(() => hours[i] = hours[i].copyWith(isClosed: !open)),
                      ),
                      if (!hours[i].isClosed) ...[
                        TextButton(
                          onPressed: () => _pickTime(i, isOpenTime: true),
                          child: Text(hours[i].openTime?.format(context) ?? 'Start'),
                        ),
                        const Text('–'),
                        TextButton(
                          onPressed: () => _pickTime(i, isOpenTime: false),
                          child: Text(hours[i].closeTime?.format(context) ?? 'End'),
                        ),
                      ] else
                        const Text('Off'),
                    ],
                  ),
                const SizedBox(height: 24),
                if (saveState.hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      saveState.error.toString(),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                FilledButton(
                  onPressed: saveState.isLoading ? null : _save,
                  child: saveState.isLoading
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
