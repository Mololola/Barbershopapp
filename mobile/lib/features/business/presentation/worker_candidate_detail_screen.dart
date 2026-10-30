import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_network_image.dart';
import '../../../core/l10n.dart';
import '../../../core/loading.dart';
import '../../../core/theme.dart';
import '../../feed/application/feed_controller.dart';
import '../../messaging/application/messaging_controller.dart';
import '../../messaging/domain/conversation.dart';
import '../../worker/domain/worker_invitation.dart';
import '../../worker/domain/worker_profile.dart';
import '../application/business_controller.dart';

class WorkerCandidateDetailScreen extends ConsumerWidget {
  const WorkerCandidateDetailScreen({super.key, required this.candidate});

  final WorkerSearchResult candidate;

  Future<void> _sendInvite(BuildContext context, WidgetRef ref) async {
    await ref.read(workerControllerProvider.notifier).inviteWorker(candidate.profileId);
    if (!context.mounted) return;
    if (!ref.read(workerControllerProvider).hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.invitationSentTo(candidate.legalFullName))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(workerControllerProvider);
    final sentInvitations = ref.watch(sentInvitationsProvider).value ?? const [];
    final pendingInvitation = sentInvitations
        .where((inv) => inv.workerProfileId == candidate.profileId && inv.status == InvitationStatus.pending)
        .firstOrNull;
    final pinnedPosts = ref.watch(pinnedPostsProvider(candidate.profileId));
    final isOnStaff =
        ref.watch(workersProvider).value?.any((worker) => worker.profileId == candidate.profileId) ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(candidate.legalFullName)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (candidate.averageRating != null)
                _StatChip(icon: Icons.star, label: candidate.averageRating!.toStringAsFixed(1)),
              if (candidate.shopsWorkedCount != null)
                _StatChip(
                  icon: Icons.storefront_outlined,
                  label: context.l10n.shopsCount(candidate.shopsWorkedCount!),
                ),
              if (candidate.yearsExperience != null)
                _StatChip(icon: Icons.work_outline, label: context.l10n.yearsShort(candidate.yearsExperience!)),
            ],
          ),
          if (candidate.city != null) ...[
            const SizedBox(height: 20),
            Text(context.l10n.city, style: Theme.of(context).textTheme.titleMedium),
            Text(candidate.city!),
          ],
          if (candidate.bio != null) ...[
            const SizedBox(height: 16),
            Text(context.l10n.bio, style: Theme.of(context).textTheme.titleMedium),
            Text(candidate.bio!),
          ],
          const SizedBox(height: 24),
          Text(context.l10n.portfolio, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          pinnedPosts.when(
            loading: () => const LoadingView(),
            error: (error, _) => Text(describeError(context.l10n, error)),
            data: (posts) {
              if (posts.isEmpty) {
                return Text(context.l10n.noPinnedWork, style: const TextStyle(color: AppColors.steel));
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final url = posts[index].mediaUrl;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: url != null
                        ? AppNetworkImage(url)
                        : ColoredBox(
                            color: AppColors.divider,
                            child: const Icon(Icons.content_cut, color: AppColors.steel),
                          ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
          if (actionState.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                describeError(context.l10n, actionState.error),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton(
            onPressed: (actionState.isLoading || pendingInvitation != null || isOnStaff)
                ? null
                : () => _sendInvite(context, ref),
            child: actionState.isLoading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(isOnStaff
                    ? context.l10n.alreadyOnStaff
                    : pendingInvitation != null
                        ? context.l10n.invitationAwaiting
                        : context.l10n.sendInvite),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(context.l10n.message),
            onPressed: () async {
              final conversationId = await ref
                  .read(messagingActionControllerProvider.notifier)
                  .startOrGetConversation(candidate.profileId, type: ConversationType.business);
              if (context.mounted) context.push('/messages/$conversationId');
            },
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.brass),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
