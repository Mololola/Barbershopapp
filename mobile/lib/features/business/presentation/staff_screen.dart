import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/loading.dart';
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
        title: const Text('Add staff member'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              const Text(
                "For staff without an app account. Someone with an account? Use \"Invite by name\" "
                'instead so their profile, schedule, and history stay linked to them.',
                style: TextStyle(fontSize: 12, color: AppColors.steel),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Add'),
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
          title: const Text('Invite by name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(labelText: 'Legal first name'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(labelText: 'Legal last name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: secondLastNameController,
                decoration: const InputDecoration(
                  labelText: 'Legal second last name (optional, disambiguates same-name matches)',
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
                          errorText = 'No worker looking for work with that name.';
                        });
                        return;
                      }
                      if (matches.length > 1) {
                        setDialogState(() {
                          isSubmitting = false;
                          errorText =
                              'Multiple workers match that name — add a second last name to narrow it down.';
                        });
                        return;
                      }
                      try {
                        await ref
                            .read(workerControllerProvider.notifier)
                            .inviteWorker(matches.first.profileId);
                        if (context.mounted) Navigator.pop(context);
                      } catch (error) {
                        setDialogState(() {
                          isSubmitting = false;
                          errorText = error.toString();
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send invite'),
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
          title: const Text('Staff'),
          actions: [
            TextButton(
              onPressed: () => _showInviteByNameDialog(context, ref),
              child: const Text('Invite by name', style: TextStyle(color: Colors.white)),
            ),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'My Workforce'), Tab(text: 'Available Workers')],
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
          error: (error, _) => Text('Error: $error'),
          data: (list) {
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No staff yet — add your first team member.'),
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
          child: Text('Sent invitations', style: Theme.of(context).textTheme.titleMedium),
        ),
        sentInvitations.when(
          loading: () => const LoadingView(),
          error: (error, _) => Text('Error: $error'),
          data: (list) {
            if (list.isEmpty) {
              return const Padding(padding: EdgeInsets.all(16), child: Text('No invitations sent yet.'));
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
                      title: Text(invitation.workerLegalFullName ?? invitation.workerUsername ?? 'Unknown'),
                      subtitle: Text(_formatDate(invitation.createdAt.toLocal())),
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

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

class _WorkforceTile extends ConsumerWidget {
  const _WorkforceTile({required this.worker, this.leaveRequest});

  final Worker worker;
  final WorkerLeaveRequest? leaveRequest;

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
              ? const Text('No app account', style: TextStyle(color: AppColors.steel, fontSize: 12))
              : null,
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove from staff',
            onPressed: () => ref.read(workerControllerProvider.notifier).removeWorker(worker.id!),
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
                  children: const [
                    Icon(Icons.info_outline, color: AppColors.rust, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('Has asked to leave.')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: actionState.isLoading
                          ? null
                          : () => ref.read(leaveRequestControllerProvider.notifier).reject(leaveRequest!),
                      child: const Text('Reject'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.rust),
                      onPressed: actionState.isLoading
                          ? null
                          : () =>
                              ref.read(leaveRequestControllerProvider.notifier).acknowledge(leaveRequest!),
                      child: const Text('Acknowledge'),
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
            decoration: const InputDecoration(hintText: 'Search by name', prefixIcon: Icon(Icons.search)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('4+ ★ rating'),
                selected: _minRating,
                onSelected: (value) {
                  setState(() => _minRating = value);
                  _applyFilters();
                },
              ),
              FilterChip(
                label: const Text('2+ shops'),
                selected: _minShops,
                onSelected: (value) {
                  setState(() => _minShops = value);
                  _applyFilters();
                },
              ),
              FilterChip(
                label: const Text('3+ yrs experience'),
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
            error: (error, _) => Center(child: Text('Error: $error')),
            data: (list) {
              if (list.isEmpty) {
                return const Center(child: Text('No one matches right now.'));
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
                          '${candidate.shopsWorkedCount} shop${candidate.shopsWorkedCount == 1 ? '' : 's'}',
                        if (candidate.yearsExperience != null) '${candidate.yearsExperience} yrs exp',
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
