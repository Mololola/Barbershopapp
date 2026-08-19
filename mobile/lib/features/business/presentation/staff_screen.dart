import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/loading.dart';
import '../../worker/presentation/invitation_status_style.dart';
import '../application/business_controller.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  Future<void> _showAddWorkerDialog(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add staff member'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
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
                      await ref
                          .read(workerControllerProvider.notifier)
                          .inviteWorker(matches.first.profileId);
                      if (context.mounted) Navigator.pop(context);
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
            tabs: [Tab(text: 'My Staff'), Tab(text: 'Marketplace')],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: null,
          onPressed: () => _showAddWorkerDialog(context, ref),
          child: const Icon(Icons.add),
        ),
        body: TabBarView(
          children: [
            _MyStaffTab(),
            const _MarketplaceTab(),
          ],
        ),
      ),
    );
  }
}

class _MyStaffTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workers = ref.watch(workersProvider);
    final sentInvitations = ref.watch(sentInvitationsProvider);

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
                  ListTile(
                    title: Text(worker.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref.read(workerControllerProvider.notifier).deleteWorker(worker.id!),
                    ),
                    onTap: worker.id == null
                        ? null
                        : () => context.push(
                              '/business/staff/${worker.id}/schedule',
                              extra: worker.name,
                            ),
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
            return Column(
              children: [
                for (final invitation in list)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: Icon(invitation.status.icon, color: invitation.status.color),
                      title: Text(invitation.workerLegalFullName ?? invitation.workerUsername ?? 'Unknown'),
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

class _MarketplaceTab extends ConsumerWidget {
  const _MarketplaceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(workersLookingForWorkProvider);

    return candidates.when(
      loading: () => const LoadingView(),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No one is looking for work right now.'));
        }
        return ListView(
          children: [
            for (final candidate in list)
              ListTile(
                title: Text(candidate.legalFullName),
                subtitle: candidate.city != null ? Text(candidate.city!) : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/business/browse-workers/${candidate.profileId}', extra: candidate),
              ),
          ],
        );
      },
    );
  }
}
