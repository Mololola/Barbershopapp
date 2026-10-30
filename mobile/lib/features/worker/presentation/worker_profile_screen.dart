import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/skeleton.dart';
import '../../../core/theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../business/domain/business.dart';
import '../application/worker_controller.dart';
import '../domain/worker_invitation.dart';

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
  bool _hasSavedProfile = false;
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

  /// A declined shop would have to invite again, so this asks first.
  Future<void> _decline(WorkerInvitation invitation) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.declineInvitationTitle(invitation.businessName)),
        content: Text(l10n.declineInvitationBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.keepIt)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.decline)),
        ],
      ),
    );
    if (confirmed == true) await ref.read(invitationControllerProvider.notifier).decline(invitation.id);
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
    final textTheme = Theme.of(context).textTheme;

    workerProfileAsync.whenData((profile) {
      if (_initialized) return;
      _initialized = true;
      if (profile != null) {
        _isWorker = true;
        _hasSavedProfile = true;
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

    final invitations = invitationsAsync.value ?? const <WorkerInvitation>[];

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.workerProfile)),
      // Within thumb reach and always visible, rather than mid-page.
      bottomNavigationBar: _isWorker
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (saveState.hasError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          describeError(context.l10n, saveState.error),
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
                ),
              ),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // A job offer waiting on an answer is the most time-sensitive
              // thing here, so it comes first and only when there is one.
              if (invitations.isNotEmpty) ...[
                Text(context.l10n.invitations, style: textTheme.titleMedium),
                const SizedBox(height: 8),
                if (invitationState.hasError)
                  Text(
                    describeError(context.l10n, invitationState.error),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                for (final invitation in invitations)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(invitation.businessName, style: textTheme.titleSmall),
                          Text(context.l10n.wantsToAddYou, style: const TextStyle(color: AppColors.steel)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: invitationState.isLoading ? null : () => _decline(invitation),
                                child: Text(context.l10n.decline),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: invitationState.isLoading
                                    ? null
                                    : () => ref.read(invitationControllerProvider.notifier).accept(invitation),
                                child: Text(context.l10n.accept),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const Divider(height: 40),
              ],
              Text(context.l10n.currentJob, style: textTheme.titleMedium),
              if (jobState.hasError)
                Text(
                  describeError(context.l10n, jobState.error),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              currentJobAsync.when(
                loading: () => const SkeletonLines(count: 2),
                error: (error, _) => Text(describeError(context.l10n, error)),
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
              const Divider(height: 40),
              // Once a profile exists, "Looking for work" is what hides it
              // from shops; there's no way to delete one, so no off switch
              // that would quietly do nothing.
              if (!_hasSavedProfile)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.availableAsWorker),
                  subtitle: Text(context.l10n.availableAsWorkerSub),
                  value: _isWorker,
                  onChanged: (value) => setState(() => _isWorker = value),
                ),
              if (_isWorker)
                Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListenableBuilder(
                        listenable: Listenable.merge([
                          _legalFirstNameController,
                          _legalLastNameController,
                        ]),
                        builder: (context, _) => SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.l10n.lookingForWork),
                          subtitle: Text(
                            _hasRequiredName ? context.l10n.lookingForWorkSub : context.l10n.addLegalNameFirst,
                          ),
                          value: _hasRequiredName && _isLookingForWork,
                          onChanged: _hasRequiredName
                              ? (value) => setState(() => _isLookingForWork = value)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(context.l10n.useRealNameHint, style: const TextStyle(color: AppColors.steel)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _legalFirstNameController,
                        decoration: InputDecoration(labelText: context.l10n.legalFirstName),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty) ? context.l10n.requiredField : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _legalLastNameController,
                        decoration: InputDecoration(labelText: context.l10n.legalLastName),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty) ? context.l10n.requiredField : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _legalSecondLastNameController,
                        decoration: InputDecoration(labelText: context.l10n.legalSecondLastNameOptional),
                        textCapitalization: TextCapitalization.words,
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
                        textCapitalization: TextCapitalization.sentences,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty) ? context.l10n.requiredField : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _cityController,
                        decoration: InputDecoration(labelText: context.l10n.city),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty) ? context.l10n.requiredField : null,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
