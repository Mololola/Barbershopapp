import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/worker_controller.dart';
import 'invitation_status_style.dart';

class WorkerProfileScreen extends ConsumerStatefulWidget {
  const WorkerProfileScreen({super.key});

  @override
  ConsumerState<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends ConsumerState<WorkerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _legalFirstNameController = TextEditingController();
  final _legalLastNameController = TextEditingController();
  final _legalSecondLastNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  bool _isWorker = false;
  bool _isLookingForWork = true;
  bool _initialized = false;

  @override
  void dispose() {
    _legalFirstNameController.dispose();
    _legalLastNameController.dispose();
    _legalSecondLastNameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  bool get _hasRequiredName =>
      _legalFirstNameController.text.trim().isNotEmpty &&
      _legalLastNameController.text.trim().isNotEmpty;

  Future<void> _save() async {
    // Opting out of worker mode (without ever having a profile) has nothing
    // to persist — there's no "delete my worker profile" flow yet.
    if (!_isWorker) return;
    if (!_formKey.currentState!.validate()) return;

    await ref.read(workerProfileControllerProvider.notifier).save(
          legalFirstName: _legalFirstNameController.text.trim(),
          legalLastName: _legalLastNameController.text.trim(),
          legalSecondLastName: _legalSecondLastNameController.text.trim().isEmpty
              ? null
              : _legalSecondLastNameController.text.trim(),
          bio: _bioController.text.trim(),
          city: _cityController.text.trim(),
          isLookingForWork: _hasRequiredName && _isLookingForWork,
        );
  }

  @override
  Widget build(BuildContext context) {
    final workerProfileAsync = ref.watch(currentWorkerProfileProvider);
    final invitationsAsync = ref.watch(receivedInvitationsProvider);
    final currentJobAsync = ref.watch(currentJobProvider);
    final saveState = ref.watch(workerProfileControllerProvider);
    final invitationState = ref.watch(invitationControllerProvider);
    final jobState = ref.watch(jobControllerProvider);

    workerProfileAsync.whenData((profile) {
      if (_initialized) return;
      _initialized = true;
      if (profile != null) {
        _isWorker = true;
        _isLookingForWork = profile.isLookingForWork;
        _legalFirstNameController.text = profile.legalFirstName;
        _legalLastNameController.text = profile.legalLastName;
        _legalSecondLastNameController.text = profile.legalSecondLastName ?? '';
        _bioController.text = profile.bio ?? '';
        _cityController.text = profile.city ?? '';
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Worker profile')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SwitchListTile(
            title: const Text('Available as worker'),
            subtitle: const Text('Let barbershops find and invite you as staff'),
            value: _isWorker,
            onChanged: (value) => setState(() => _isWorker = value),
          ),
          if (_isWorker) ...[
            const SizedBox(height: 8),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text(
                    'Use your real name — this is what businesses and customers will see '
                    'you as once you accept a job.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  TextFormField(
                    controller: _legalFirstNameController,
                    decoration: const InputDecoration(labelText: 'Legal first name'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _legalLastNameController,
                    decoration: const InputDecoration(labelText: 'Legal last name'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _legalSecondLastNameController,
                    decoration: const InputDecoration(labelText: 'Legal second last name (optional)'),
                  ),
                  TextFormField(
                    controller: _bioController,
                    decoration: const InputDecoration(labelText: 'Experience / bio'),
                    maxLines: 3,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'City'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Required' : null,
                  ),
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      _legalFirstNameController,
                      _legalLastNameController,
                    ]),
                    builder: (context, _) => SwitchListTile(
                      title: const Text('Looking for work'),
                      subtitle: _hasRequiredName
                          ? null
                          : const Text('Add your legal first and last name first'),
                      value: _hasRequiredName && _isLookingForWork,
                      onChanged: _hasRequiredName
                          ? (value) => setState(() => _isLookingForWork = value)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (saveState.hasError)
            Text(
              saveState.error.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            onPressed: saveState.isLoading ? null : _save,
            child: saveState.isLoading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
          const Divider(height: 48),
          Text('Current job', style: Theme.of(context).textTheme.titleMedium),
          if (jobState.hasError)
            Text(
              jobState.error.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          currentJobAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Error: $error'),
            data: (job) {
              if (job == null) {
                return const Text('Not currently working at a business.');
              }
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(job.businessName ?? 'A business'),
                trailing: TextButton(
                  onPressed:
                      jobState.isLoading ? null : () => ref.read(jobControllerProvider.notifier).leave(job.id!),
                  child: const Text('Leave'),
                ),
              );
            },
          ),
          const Divider(height: 48),
          Text('Invitations', style: Theme.of(context).textTheme.titleMedium),
          if (invitationState.hasError)
            Text(
              invitationState.error.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          invitationsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Error: $error'),
            data: (invitations) {
              if (invitations.isEmpty) {
                return const Text('No pending invitations.');
              }
              return Column(
                children: [
                  for (final invitation in invitations)
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(invitation.status.icon, color: invitation.status.color),
                        title: Text(invitation.businessName),
                        subtitle: const Text('wants to add you as staff'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              tooltip: 'Accept',
                              onPressed: invitationState.isLoading
                                  ? null
                                  : () => ref
                                      .read(invitationControllerProvider.notifier)
                                      .accept(invitation),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              tooltip: 'Decline',
                              onPressed: invitationState.isLoading
                                  ? null
                                  : () => ref
                                      .read(invitationControllerProvider.notifier)
                                      .decline(invitation.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
