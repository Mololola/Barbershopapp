import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/loading.dart';
import '../../auth/application/auth_controller.dart';
import '../../business/domain/business.dart';
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
  final _yearsExperienceController = TextEditingController();
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
    _yearsExperienceController.dispose();
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
          yearsExperience: int.tryParse(_yearsExperienceController.text.trim()),
          isLookingForWork: _hasRequiredName && _isLookingForWork,
        );
    if (!mounted) return;
    if (!ref.read(workerProfileControllerProvider).hasError) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.profileSaved)));
    }
  }

  Future<void> _requestLeave(Worker job) async {
    await ref.read(jobControllerProvider.notifier).requestLeave(job);
    if (!mounted) return;
    if (!ref.read(jobControllerProvider).hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.askedShopToConfirmLeaving(job.businessName ?? context.l10n.theShop))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final workerProfileAsync = ref.watch(currentWorkerProfileProvider);
    final invitationsAsync = ref.watch(receivedInvitationsProvider);
    final currentJobAsync = ref.watch(currentJobProvider);
    final pendingLeaveRequest = ref.watch(pendingLeaveRequestProvider).value;
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
        _yearsExperienceController.text = profile.yearsExperience?.toString() ?? '';
      }
    });

    // No employment relationships for a minor account — see the
    // guardian-consent design (profiles_minor_role_check / the
    // owner-insert-worker-profile RLS policy actually enforce this).
    if (ref.watch(currentProfileProvider).value?.isMinor == true) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.workerProfile)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(context.l10n.workerMarketplaceUnavailable),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.workerProfile)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SwitchListTile(
            title: Text(context.l10n.availableAsWorker),
            subtitle: Text(context.l10n.availableAsWorkerSub),
            value: _isWorker,
            onChanged: (value) => setState(() => _isWorker = value),
          ),
          if (_isWorker) ...[
            const SizedBox(height: 8),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  Text(
                    context.l10n.useRealNameHint,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _legalFirstNameController,
                    decoration: InputDecoration(labelText: context.l10n.legalFirstName),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? context.l10n.requiredField : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _legalLastNameController,
                    decoration: InputDecoration(labelText: context.l10n.legalLastName),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? context.l10n.requiredField : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _legalSecondLastNameController,
                    decoration: InputDecoration(labelText: context.l10n.legalSecondLastNameOptional),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _yearsExperienceController,
                    decoration: InputDecoration(labelText: context.l10n.yearsExperienceOptional),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      return int.tryParse(value.trim()) == null ? context.l10n.enterAWholeNumber : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bioController,
                    decoration: InputDecoration(labelText: context.l10n.experienceBio),
                    maxLines: 3,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? context.l10n.requiredField : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cityController,
                    decoration: InputDecoration(labelText: context.l10n.city),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? context.l10n.requiredField : null,
                  ),
                  const SizedBox(height: 8),
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      _legalFirstNameController,
                      _legalLastNameController,
                    ]),
                    builder: (context, _) => SwitchListTile(
                      title: Text(context.l10n.lookingForWork),
                      subtitle: _hasRequiredName
                          ? null
                          : Text(context.l10n.addLegalNameFirst),
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
                : Text(context.l10n.save),
          ),
          const Divider(height: 48),
          Text(context.l10n.currentJob, style: Theme.of(context).textTheme.titleMedium),
          if (jobState.hasError)
            Text(
              jobState.error.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          currentJobAsync.when(
            loading: () => const LoadingView(),
            error: (error, _) => Text(context.l10n.errorWithDetail('$error')),
            data: (job) {
              if (job == null) {
                return Text(context.l10n.notCurrentlyWorking);
              }
              // Leaving isn't unilateral — this only files the request; the
              // job stays active (and this button stays disabled) until the
              // business confirms it, so a misclick can't drop someone from
              // the schedule on the spot.
              final isPending = pendingLeaveRequest != null && pendingLeaveRequest.workerId == job.id;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(job.businessName ?? context.l10n.aBusiness),
                subtitle: isPending ? Text(context.l10n.leaveRequestSent) : null,
                trailing: TextButton(
                  onPressed: (jobState.isLoading || isPending) ? null : () => _requestLeave(job),
                  child: Text(context.l10n.requestToLeave),
                ),
              );
            },
          ),
          const Divider(height: 48),
          Text(context.l10n.invitations, style: Theme.of(context).textTheme.titleMedium),
          if (invitationState.hasError)
            Text(
              invitationState.error.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          invitationsAsync.when(
            loading: () => const LoadingView(),
            error: (error, _) => Text(context.l10n.errorWithDetail('$error')),
            data: (invitations) {
              if (invitations.isEmpty) {
                return Text(context.l10n.noPendingInvitations);
              }
              return Column(
                children: [
                  for (final invitation in invitations)
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(invitation.status.icon, color: invitation.status.color),
                        title: Text(invitation.businessName),
                        subtitle: Text(context.l10n.wantsToAddYou),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              tooltip: context.l10n.accept,
                              onPressed: invitationState.isLoading
                                  ? null
                                  : () => ref
                                      .read(invitationControllerProvider.notifier)
                                      .accept(invitation),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              tooltip: context.l10n.decline,
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
