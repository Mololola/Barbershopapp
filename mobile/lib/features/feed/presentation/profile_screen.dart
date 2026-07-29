import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/domain/profile.dart';
import '../../messaging/application/messaging_controller.dart';
import '../../worker/application/worker_controller.dart';
import '../application/feed_controller.dart';
import 'post_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileByIdProvider(profileId));
    final myProfile = ref.watch(currentProfileProvider).value;
    final posts = ref.watch(postsByAuthorProvider(profileId));
    final isMine = profileId == myProfile?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(profile.value?.username ?? 'Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/profile/search'),
          ),
          if (isMine)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/profile/edit'),
            ),
        ],
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (value) {
          if (value == null) {
            return const Center(child: Text('Profile not found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: value.avatarUrl != null ? NetworkImage(value.avatarUrl!) : null,
                    child: value.avatarUrl == null ? const Icon(Icons.person, size: 32) : null,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value.username, style: Theme.of(context).textTheme.titleLarge),
                      Text(value.role == AccountRole.business ? 'Business' : 'Customer'),
                    ],
                  ),
                ],
              ),
              if (!isMine) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Message'),
                  onPressed: () async {
                    final conversationId = await ref
                        .read(messagingActionControllerProvider.notifier)
                        .startOrGetConversation(profileId);
                    if (context.mounted) context.push('/messages/$conversationId');
                  },
                ),
              ],
              if (value.role == AccountRole.customer) ...[
                const SizedBox(height: 24),
                _WorkerStatusLine(profileId: profileId),
              ],
              const SizedBox(height: 24),
              Text('Posts', style: Theme.of(context).textTheme.titleMedium),
              posts.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Text('Error: $error'),
                data: (list) {
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No posts yet.'),
                    );
                  }
                  return Column(
                    children: [
                      for (final post in list) PostCard(post: post, isMine: post.authorId == myProfile?.id),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A single line — no employer/city/looking-for-work detail here, that
/// belongs to the business-side worker-browse screen instead (see
/// features/business/presentation/worker_candidate_detail_screen.dart).
class _WorkerStatusLine extends ConsumerWidget {
  const _WorkerStatusLine({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workerProfile = ref.watch(workerProfileByIdProvider(profileId));

    return workerProfile.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, _) => Text('Error: $error'),
      data: (value) {
        if (value == null) return const SizedBox.shrink();
        return Text('Worker status: Barber', style: Theme.of(context).textTheme.titleMedium);
      },
    );
  }
}
