import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n.dart';
import '../../../core/loading.dart';
import '../../../core/responsive.dart';
import '../../../core/theme.dart';
import '../../worker/domain/worker_invitation.dart';
import '../../worker/domain/worker_leave_request.dart';
import '../../worker/presentation/invitation_status_style.dart';
import '../application/business_controller.dart';
import '../domain/business.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key, this.setupFooter});

  /// Shown pinned to the bottom when this screen is a step of the
  /// onboarding wizard (see BusinessSetupScreen).
  final Widget? setupFooter;

  Future<void> _showAddWorkerDialog(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.addStaffMember),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: context.l10n.name),
                validator: (value) => (value == null || value.trim().isEmpty) ? context.l10n.requiredField : null,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.addStaffHint,
                style: const TextStyle(fontSize: 12, color: AppColors.steel),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: Text(context.l10n.add),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(workerControllerProvider.notifier).addWorker(nameController.text.trim());
  }

  Future<void> _showInviteByNameDialog(BuildContext context, WidgetRef ref) async {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final secondLastNameController = TextEditingController();
    String? errorText;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.inviteByName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                decoration: InputDecoration(labelText: context.l10n.legalFirstName),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: lastNameController,
                decoration: InputDecoration(labelText: context.l10n.legalLastName),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: secondLastNameController,
                decoration: InputDecoration(
                  labelText: context.l10n.legalSecondLastName,
                ),
              ),
              if (errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(errorText!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() {
                        isSubmitting = true;
                        errorText = null;
                      });
                      final matches = await ref.read(workerControllerProvider.notifier).findWorkersByName(
                            firstName: firstNameController.text.trim(),
                            lastName: lastNameController.text.trim(),
                            secondLastName: secondLastNameController.text.trim().isEmpty
                                ? null
                                : secondLastNameController.text.trim(),
                          );
                      if (matches.isEmpty) {
                        setDialogState(() {
                          isSubmitting = false;
                          errorText = context.l10n.noWorkerWithName;
                        });
                        return;
                      }
                      if (matches.length > 1) {
                        setDialogState(() {
                          isSubmitting = false;
                          errorText = context.l10n.multipleWorkersMatch;
                        });
                        return;
                      }
                      // inviteWorker reports failure through the controller's
                      // state (AsyncValue.guard), not by throwing.
                      await ref.read(workerControllerProvider.notifier).inviteWorker(matches.first.profileId);
                      final result = ref.read(workerControllerProvider);
                      if (result.hasError) {
                        setDialogState(() {
                          isSubmitting = false;
                          errorText = result.error.toString();
                        });
                        return;
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
              child: isSubmitting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.l10n.sendInvite),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.navStaff),
          actions: [
            TextButton(
              onPressed: () => _showInviteByNameDialog(context, ref),
              // White on the phone's dark app bar; the desktop header is light.
              child: Text(context.l10n.inviteByName, style: TextStyle(color: isWideLayout(context) ? null : Colors.white)),
            ),
          ],
          bottom: TabBar(
            tabs: [Tab(text: context.l10n.myWorkforce), Tab(text: context.l10n.availableWorkers)],
          ),
        ),
        bottomNavigationBar: setupFooter,
        floatingActionButton: FloatingActionButton(
          heroTag: null,
          onPressed: () => _showAddWorkerDialog(context, ref),
          child: const Icon(Icons.add),
        ),
        body: const TabBarView(
          children: [
            _MyWorkforceTab(),
            _AvailableWorkersTab(),
          ],
        ),
      ),
    );
  }
}

class _MyWorkforceTab extends ConsumerWidget {
  const _MyWorkforceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workers = ref.watch(workersProvider);
    final sentInvitations = ref.watch(sentInvitationsProvider);
    final leaveRequests = ref.watch(pendingLeaveRequestsProvider).value ?? const [];

    return ListView(
      children: [
        workers.when(
          loading: () => const LoadingView(),
          error: (error, _) => Text(context.l10n.errorWithDetail('$error')),
          data: (list) {
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.l10n.noStaffAddFirst),
              );
            }
            return Column(
              children: [
                for (final worker in list)
                  _WorkforceTile(
                    worker: worker,
                    leaveRequest: leaveRequests.where((r) => r.workerId == worker.id).firstOrNull,
                  ),
              ],
            );
          },
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(context.l10n.sentInvitations, style: Theme.of(context).textTheme.titleMedium),
        ),
        sentInvitations.when(
          loading: () => const LoadingView(),
          error: (error, _) => Text(context.l10n.errorWithDetail('$error')),
          data: (list) {
            if (list.isEmpty) {
              return Padding(padding: const EdgeInsets.all(16), child: Text(context.l10n.noInvitationsSent));
            }
            // The full history can pile up across repeated invite/accept/
            // leave cycles with the same person — what a business actually
            // wants here is the current state per worker, not every past
            // attempt, so only the most recent invitation to each person is
            // shown (list is already newest-first from the repository).
            final latestPerWorker = <String, WorkerInvitation>{};
            for (final invitation in list) {
              latestPerWorker.putIfAbsent(invitation.workerProfileId, () => invitation);
            }
            return Column(
              children: [
                for (final invitation in latestPerWorker.values)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: Icon(invitation.status.icon, color: invitation.status.color),
                      title: Text(invitation.workerLegalFullName ?? invitation.workerUsername ?? context.l10n.unknown),
                      subtitle: Text(DateFormat.yMMMd(context.l10n.localeName).format(invitation.createdAt.toLocal())),
                      trailing: Chip(
                        label: Text(invitation.status.label),
                        backgroundColor: invitation.status.color.withValues(alpha: 0.15),
                        labelStyle: TextStyle(color: invitation.status.color),
                        side: BorderSide.none,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _WorkforceTile extends ConsumerWidget {
  const _WorkforceTile({required this.worker, this.leaveRequest});

  final Worker worker;
  final WorkerLeaveRequest? leaveRequest;

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.removeFromStaffTitle(worker.name)),
        content: Text(context.l10n.removeFromStaffBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.remove)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // Captured now: on success this tile leaves the list and unmounts.
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(workerControllerProvider.notifier).removeWorker(worker.id!);
    final result = ref.read(workerControllerProvider);
    if (result.hasError) messenger.showSnackBar(SnackBar(content: Text(result.error.toString())));
  }

  Future<void> _acknowledgeLeave(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(leaveRequestControllerProvider.notifier).acknowledge(leaveRequest!);
    final result = ref.read(leaveRequestControllerProvider);
    if (result.hasError) messenger.showSnackBar(SnackBar(content: Text(result.error.toString())));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(leaveRequestControllerProvider);

    return Column(
      children: [
        ListTile(
          title: Text(worker.name),
          // Distinguishes a manually-added roster entry from a real account
          // — matching names between the two are otherwise indistinguishable
          // in the UI, which reads as a sync bug even though they're two
          // unrelated rows.
          subtitle: worker.profileId == null
              ? Text(context.l10n.noAppAccount, style: const TextStyle(color: AppColors.steel, fontSize: 12))
              : null,
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: context.l10n.removeFromStaff,
            onPressed: () => _confirmRemove(context, ref),
          ),
          onTap: worker.id == null
              ? null
              : () => context.push('/business/staff/${worker.id}/schedule', extra: worker.name),
        ),
        if (leaveRequest != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.rust.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.rust.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.rust, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(context.l10n.hasAskedToLeave)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: actionState.isLoading
                          ? null
                          : () => ref.read(leaveRequestControllerProvider.notifier).reject(leaveRequest!),
                      child: Text(context.l10n.reject),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.rust),
                      onPressed: actionState.isLoading
                          ? null
                          : () => _acknowledgeLeave(context, ref),
                      child: Text(context.l10n.acknowledge),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AvailableWorkersTab extends ConsumerStatefulWidget {
  const _AvailableWorkersTab();

  @override
  ConsumerState<_AvailableWorkersTab> createState() => _AvailableWorkersTabState();
}

class _AvailableWorkersTabState extends ConsumerState<_AvailableWorkersTab> {
  final _queryController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  bool _minRating = false;
  bool _minShops = false;
  bool _minExperience = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(marketplaceControllerProvider.notifier).loadMore();
    }
  }

  void _applyFilters() {
    ref.read(marketplaceControllerProvider.notifier).applyFilters(
          MarketplaceFilters(
            nameQuery: _queryController.text.trim().isEmpty ? null : _queryController.text.trim(),
            minAverageRating: _minRating ? 4.0 : null,
            minShopsWorked: _minShops ? 2 : null,
            minYearsExperience: _minExperience ? 3 : null,
          ),
        );
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _applyFilters);
  }

  @override
  Widget build(BuildContext context) {
    final candidates = ref.watch(marketplaceControllerProvider);
    final controller = ref.read(marketplaceControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _queryController,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(hintText: context.l10n.searchByName, prefixIcon: const Icon(Icons.search)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: Text(context.l10n.filterRating),
                selected: _minRating,
                onSelected: (value) {
                  setState(() => _minRating = value);
                  _applyFilters();
                },
              ),
              FilterChip(
                label: Text(context.l10n.filterShops),
                selected: _minShops,
                onSelected: (value) {
                  setState(() => _minShops = value);
                  _applyFilters();
                },
              ),
              FilterChip(
                label: Text(context.l10n.filterExperience),
                selected: _minExperience,
                onSelected: (value) {
                  setState(() => _minExperience = value);
                  _applyFilters();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: candidates.when(
            loading: () => const LoadingView(),
            error: (error, _) => Center(child: Text(context.l10n.errorWithDetail('$error'))),
            data: (list) {
              if (list.isEmpty) {
                return Center(child: Text(context.l10n.noOneMatches));
              }
              return ListView.builder(
                controller: _scrollController,
                itemCount: list.length + 1,
                itemBuilder: (context, index) {
                  if (index == list.length) {
                    return controller.hasMore
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: SizedBox(height: 32, child: BarberPoleLoader(size: 24))),
                          )
                        : const SizedBox.shrink();
                  }
                  final candidate = list[index];
                  return ListTile(
                    title: Text(candidate.legalFullName),
                    subtitle: Text(
                      [
                        if (candidate.city != null) candidate.city!,
                        if (candidate.averageRating != null)
                          '★ ${candidate.averageRating!.toStringAsFixed(1)}',
                        if (candidate.shopsWorkedCount != null)
                          context.l10n.shopsCount(candidate.shopsWorkedCount!),
                        if (candidate.yearsExperience != null) context.l10n.yearsExpShort(candidate.yearsExperience!),
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/business/browse-workers/${candidate.profileId}', extra: candidate),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
