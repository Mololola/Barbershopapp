import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/loading.dart';
import '../application/business_controller.dart';
import '../domain/business.dart';
import 'opening_hours_editor.dart';

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
    _hours ??= OpeningHours.fullWeek(existing);
  }

  Future<void> _save() async {
    final hours = _hours;
    if (hours == null) return;
    if (!hours.every((day) => day.hasValidRange)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.fixHighlightedDays)));
      return;
    }
    await ref.read(workerScheduleControllerProvider.notifier).save(widget.workerId, hours);
  }

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(workerScheduleProvider(widget.workerId));
    final saveState = ref.watch(workerScheduleControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.workerSchedule(widget.workerName))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: schedule.when(
          loading: () => const LoadingView(),
          error: (error, _) => Center(child: Text(context.l10n.errorWithDetail('$error'))),
          data: (existing) {
            _seedIfNeeded(existing);
            final hours = _hours!;

            return ListView(
              children: [
                Text(
                  context.l10n.daysOffUseShopHours,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                OpeningHoursEditor(
                  hours: hours,
                  closedLabel: context.l10n.off,
                  onChanged: (i, day) => setState(() => hours[i] = day),
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
                      : Text(context.l10n.save),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
