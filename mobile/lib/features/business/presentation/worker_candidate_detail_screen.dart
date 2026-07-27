import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../worker/domain/worker_profile.dart';
import '../application/business_controller.dart';

class WorkerCandidateDetailScreen extends ConsumerWidget {
  const WorkerCandidateDetailScreen({super.key, required this.candidate});

  final WorkerSearchResult candidate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(workerControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(candidate.legalFullName)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            if (candidate.city != null) ...[
              Text('City', style: Theme.of(context).textTheme.titleMedium),
              Text(candidate.city!),
              const SizedBox(height: 16),
            ],
            if (candidate.bio != null) ...[
              Text('Bio', style: Theme.of(context).textTheme.titleMedium),
              Text(candidate.bio!),
              const SizedBox(height: 24),
            ],
            if (actionState.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  actionState.error.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: actionState.isLoading
                  ? null
                  : () => ref.read(workerControllerProvider.notifier).inviteWorker(candidate.profileId),
              child: actionState.isLoading
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Send invite'),
            ),
          ],
        ),
      ),
    );
  }
}
