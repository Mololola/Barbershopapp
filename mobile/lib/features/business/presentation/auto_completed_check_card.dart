import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n.dart';
import '../../../core/theme.dart';
import '../../customer/application/booking_controller.dart';
import '../../customer/domain/booking.dart';
import '../application/business_controller.dart';

/// On the shop's Home: bookings nobody marked, so they were completed
/// automatically and count as income in Finance. The shop says whether each
/// happened; a no-show drops out of Finance. Hidden when there's nothing to
/// check, and each booking drops off after 7 days.
class AutoCompletedCheckCard extends ConsumerWidget {
  const AutoCompletedCheckCard({super.key});

  Future<void> _answer(BuildContext context, WidgetRef ref, Booking booking, {required bool happened}) async {
    final actions = ref.read(bookingActionControllerProvider.notifier);
    if (happened) {
      await actions.completeBooking(booking.id);
    } else {
      await actions.markNoShow(booking.id);
    }
    ref.invalidate(autoCompletedToCheckProvider);
    ref.invalidate(businessBookingsProvider);
    ref.invalidate(financeOverviewProvider);
    final result = ref.read(bookingActionControllerProvider);
    if (result.hasError && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(context.l10n, result.error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toCheck = ref.watch(autoCompletedToCheckProvider).value ?? const [];
    if (toCheck.isEmpty) return const SizedBox.shrink();
    final busy = ref.watch(bookingActionControllerProvider).isLoading;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.autoCompletedCheckTitle(toCheck.length),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(l10n.autoCompletedCheckBody, style: const TextStyle(color: AppColors.steel)),
              for (final booking in toCheck) ...[
                const Divider(height: 24),
                Text(
                  '${booking.customerName ?? l10n.aCustomer} · '
                  '${DateFormat.MMMEd(l10n.localeName).format(booking.startTime.toLocal())}, '
                  '${TimeOfDay.fromDateTime(booking.startTime.toLocal()).format(context)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (booking.serviceName != null) Text(booking.serviceName!, style: const TextStyle(color: AppColors.steel)),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton(
                        onPressed: busy ? null : () => _answer(context, ref, booking, happened: false),
                        child: Text(l10n.noShow),
                      ),
                      TextButton(
                        onPressed: busy ? null : () => _answer(context, ref, booking, happened: true),
                        child: Text(l10n.itHappened),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
