import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_network_image.dart';
import '../../../core/l10n.dart';
import '../../../core/loading.dart';
import '../../../core/theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/profile.dart';
import '../../business/domain/brand.dart';
import '../../customer/application/browse_controller.dart';
import '../../customer/presentation/shop_page.dart';
import '../../messaging/application/messaging_controller.dart';
import '../../worker/application/worker_controller.dart';
import '../application/feed_controller.dart';
import '../domain/post.dart';

/// A person's profile: a charcoal header (photo, name, role and Barber
/// badges, post totals, Message / Edit profile) over a grid of their posts.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileByIdProvider(profileId));
    final myProfile = ref.watch(currentProfileProvider).value;
    final posts = ref.watch(postsByAuthorProvider(profileId));
    final isMine = profileId == myProfile?.id;

    // A business's profile is its shop page — the same one customers book
    // from — wherever it's reached from (a post's author, profile search).
    if (profile.value?.role == AccountRole.business) {
      final businessId = ref.watch(businessIdByOwnerProvider(profileId));
      if (businessId.isLoading) return const Scaffold(body: LoadingView());
      if (businessId.value != null) return ShopPage(businessId: businessId.value!, isOwner: isMine);
    }

    return Scaffold(
      appBar: AppBar(
        // The header below already names the person; the bar carries the brand.
        title: isMine
            ? const Text('Fadra', style: TextStyle(fontFamily: AppFonts.script, fontSize: 28, color: AppColors.brass))
            : null,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: context.l10n.findPeople,
            onPressed: () => context.push('/profile/search'),
          ),
          if (isMine)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: context.l10n.settingsTitle,
              onPressed: () => context.push('/account-settings'),
            ),
        ],
      ),
      body: profile.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text(describeError(context.l10n, error))),
        data: (value) {
          if (value == null) {
            return Center(child: Text(context.l10n.profileNotFound));
          }
          // No DMs to or from a minor account — see the guardian-consent design.
          final canMessage = !isMine && myProfile?.isMinor != true && value.isMinor != true;
          final list = posts.value;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  profile: value,
                  posts: list,
                  action: isMine
                      ? OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.chalk,
                            side: BorderSide(color: AppColors.chalk.withValues(alpha: 0.3)),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: Text(context.l10n.editProfile),
                          onPressed: () => context.push('/profile/edit'),
                        )
                      : canMessage
                          ? FilledButton.icon(
                              icon: const Icon(Icons.chat_bubble_outline, size: 18),
                              label: Text(context.l10n.message),
                              onPressed: () async {
                                final conversationId = await ref
                                    .read(messagingActionControllerProvider.notifier)
                                    .startOrGetConversation(profileId);
                                if (context.mounted) context.push('/messages/$conversationId');
                              },
                            )
                          : null,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    context.l10n.postsUpper,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.steel, letterSpacing: 1.2),
                  ),
                ),
              ),
              ...posts.when(
                loading: () => [const SliverToBoxAdapter(child: LoadingView())],
                error: (error, _) => [SliverToBoxAdapter(child: Center(child: Text(describeError(context.l10n, error))))],
                data: (list) => [
                  if (list.isEmpty)
                    SliverToBoxAdapter(child: _NoPosts(isMine: isMine))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(2, 0, 2, 24),
                      sliver: SliverGrid.count(
                        crossAxisCount: 3,
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                        children: [for (final post in list) _PostTile(post: post)],
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.profile, required this.posts, required this.action});

  final Profile profile;

  /// Null while the posts are loading: the totals then show a dash.
  final List<Post>? posts;
  final Widget? action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    // The same fact the old "Worker status: Barber" line showed: a worker
    // profile exists. No employer, city or availability here — that stays on
    // the business-side worker-browse screen.
    final isBarber = profile.role == AccountRole.customer &&
        ref.watch(workerProfileByIdProvider(profile.id)).value != null;
    final list = posts;

    return Container(
      color: AppColors.charcoal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _RingedAvatar(profile: profile),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.headlineMedium?.copyWith(color: AppColors.chalk),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (isBarber) _Badge(label: context.l10n.badgeBarber, icon: Icons.content_cut, filled: true),
                        _Badge(
                          label: profile.role == AccountRole.business
                              ? context.l10n.roleBusiness
                              : context.l10n.roleCustomer,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: AppColors.chalk.withValues(alpha: 0.12)),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(label: context.l10n.posts, value: list?.length),
              _Stat(label: context.l10n.likes, value: list?.fold<int>(0, (sum, p) => sum + p.likeCount)),
              _Stat(label: context.l10n.comments, value: list?.fold<int>(0, (sum, p) => sum + p.commentCount)),
            ],
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

class _RingedAvatar extends StatelessWidget {
  const _RingedAvatar({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final url = profile.avatarUrl;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.brass),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.charcoal),
        child: CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.brass.withValues(alpha: 0.2),
          foregroundColor: AppColors.brass,
          backgroundImage: url != null ? CachedNetworkImageProvider(url) : null,
          child: url == null
              ? Text(initialsOf(profile.username), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700))
              : null,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.icon, this.filled = false});

  final String label;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colour = filled ? AppColors.onBrass : AppColors.chalk.withValues(alpha: 0.85);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? AppColors.brass : null,
        border: filled ? null : Border.all(color: AppColors.chalk.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: colour), const SizedBox(width: 4)],
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colour, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value?.toString() ?? '–', style: textTheme.headlineSmall?.copyWith(color: AppColors.chalk, height: 1)),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(color: AppColors.chalk.withValues(alpha: 0.6), letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}

/// One square of the posts grid: the photo, or a dark tile for a video, or
/// the text for a text-only post; likes and comments in the corner. Opens
/// the post with its comments.
class _PostTile extends StatelessWidget {
  const _PostTile({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final media = post.mediaUrl;
    final isImage = media != null && post.mediaType == PostMediaType.image;
    final isVideo = media != null && post.mediaType == PostMediaType.video;
    const overlay = TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
    );

    return Semantics(
      button: true,
      label: context.l10n.postSemantics(post.likeCount, post.commentCount),
      child: GestureDetector(
        onTap: () => context.push('/posts/${post.id}'),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isImage)
              AppNetworkImage(media)
            else
              ColoredBox(
                color: isVideo ? AppColors.charcoal : AppColors.brass.withValues(alpha: 0.16),
                child: isVideo
                    ? const Icon(Icons.play_circle_outline, color: AppColors.chalk, size: 32)
                    : Padding(
                        padding: const EdgeInsets.all(8),
                        child: Center(
                          child: Text(
                            post.body ?? '',
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
              ),
            if (post.isPinned)
              const Positioned(top: 6, right: 6, child: Icon(Icons.push_pin, size: 16, color: Colors.white, shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
            if (isImage || isVideo)
              Positioned(
                left: 6,
                bottom: 6,
                child: Row(
                  children: [
                    const Icon(Icons.favorite, size: 12, color: Colors.white),
                    Text(' ${post.likeCount}', style: overlay),
                    if (post.commentCount > 0) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.mode_comment, size: 12, color: Colors.white),
                      Text(' ${post.commentCount}', style: overlay),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoPosts extends StatelessWidget {
  const _NoPosts({required this.isMine});

  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.brass.withValues(alpha: 0.16),
            child: const Icon(Icons.photo_outlined, color: AppColors.brass),
          ),
          const SizedBox(height: 12),
          Text(context.l10n.noPostsYetTitle, style: textTheme.titleMedium),
          if (isMine) ...[
            const SizedBox(height: 4),
            Text(
              context.l10n.showOffLatestCut,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.steel),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.l10n.shareFirstPost),
              onPressed: () => context.push('/posts/new'),
            ),
          ],
        ],
      ),
    );
  }
}
