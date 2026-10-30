import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../core/skeleton.dart';
import '../../../core/status_message.dart';
import '../../../core/theme.dart';
import '../../business/domain/brand.dart';
import '../application/messaging_controller.dart';
import '../domain/conversation.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);

    final list = conversations.value ?? const <Conversation>[];
    final personal = list.where((c) => c.type == ConversationType.personal).toList();
    final business = list.where((c) => c.type == ConversationType.business).toList();

    final unread = _unread(list);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          scrolledUnderElevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(124),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.navMessages,
                    style: const TextStyle(fontFamily: AppFonts.script, fontSize: 40, height: 1, color: AppColors.chalk),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversations.hasValue ? (unread == 0 ? context.l10n.allCaughtUpShort : context.l10n.unreadCount(unread)) : ' ',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.brass),
                  ),
                  const SizedBox(height: 16),
                  // Personal / Business as a pill switch.
                  Container(
                    height: 40,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.chalk.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      indicator: BoxDecoration(color: AppColors.chalk, borderRadius: BorderRadius.circular(9)),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerHeight: 0,
                      labelColor: AppColors.charcoal,
                      unselectedLabelColor: AppColors.chalk.withValues(alpha: 0.7),
                      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                      tabs: [
                        _InboxTab(label: context.l10n.inboxPersonal, unread: _unread(personal)),
                        _InboxTab(label: context.l10n.inboxBusiness, unread: _unread(business)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: conversations.when(
          loading: () => const SkeletonList(leading: SkeletonLeading.avatar),
          error: (_, _) => Center(
            child: StatusMessage(
              icon: Icons.wifi_off_rounded,
              title: context.l10n.couldntLoadMessages,
              message: context.l10n.checkConnection,
              actionLabel: context.l10n.tryAgain,
              onAction: () => ref.invalidate(conversationsProvider),
              isError: true,
            ),
          ),
          data: (_) => TabBarView(
            children: [
              _ConversationList(
                conversations: personal,
                empty: StatusMessage(
                  icon: Icons.chat_bubble_outline,
                  title: context.l10n.noConversationsYet,
                  message: context.l10n.noConversationsHint,
                  actionLabel: context.l10n.findPeople,
                  onAction: () => context.push('/profile/search'),
                ),
              ),
              _ConversationList(
                conversations: business,
                empty: StatusMessage(
                  icon: Icons.work_outline,
                  title: context.l10n.noWorkMessages,
                  message: context.l10n.noWorkMessagesHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static int _unread(List<Conversation> conversations) => conversations.fold(0, (sum, c) => sum + c.unreadCount);
}

/// A tab label with the inbox's unread count beside it.
class _InboxTab extends StatelessWidget {
  const _InboxTab({required this.label, required this.unread});

  final String label;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (unread > 0) ...[
            const SizedBox(width: 8),
            _UnreadBadge(count: unread),
          ],
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: AppColors.brass, borderRadius: BorderRadius.circular(10)),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(color: AppColors.onBrass, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ConversationList extends ConsumerWidget {
  const _ConversationList({required this.conversations, required this.empty});

  final List<Conversation> conversations;
  final Widget empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(conversationsProvider.future),
      child: conversations.isEmpty
          // Scrollable so pull-to-refresh still works on an empty inbox.
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(height: constraints.maxHeight, child: Center(child: empty)),
              ),
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: conversations.length,
              separatorBuilder: (_, _) => Divider(height: 1, indent: 84, color: AppColors.charcoal.withValues(alpha: 0.06)),
              itemBuilder: (context, index) => _ConversationRow(conversation: conversations[index]),
            ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unread = conversation.unreadCount > 0;
    final secondary = scheme.onSurface.withValues(alpha: 0.65);
    final avatarUrl = conversation.otherAvatarUrl;
    return Material(
      // Unread threads carry a faint brass wash, so they stand out at a glance.
      color: unread ? scheme.primary.withValues(alpha: 0.06) : Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/messages/${conversation.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Unread threads get a brass ring around the photo.
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: unread ? AppColors.brass : Colors.transparent, width: 2),
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: scheme.primary.withValues(alpha: 0.12),
                  foregroundColor: scheme.primary,
                  backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                  child: avatarUrl == null ? Text(initialsOf(conversation.otherUsername)) : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.otherUsername,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: unread ? FontWeight.w600 : null),
                          ),
                        ),
                        if (conversation.lastMessageAt != null)
                          Text(
                            _whenLabel(context, conversation.lastMessageAt!),
                            style: theme.textTheme.labelSmall?.copyWith(color: unread ? scheme.primary : secondary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.lastMessageBody ?? context.l10n.sayHello,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: unread ? scheme.onSurface : secondary,
                              fontWeight: unread ? FontWeight.w600 : null,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          _UnreadBadge(count: conversation.unreadCount),
                        ],
                      ],
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

/// Today shows the time, this week the weekday, older the date.
String _whenLabel(BuildContext context, DateTime at) {
  final local = at.toLocal();
  final today = DateUtils.dateOnly(DateTime.now());
  final days = (today.difference(DateUtils.dateOnly(local)).inHours / 24).round();
  if (days <= 0) return TimeOfDay.fromDateTime(local).format(context);
  if (days == 1) return context.l10n.yesterday;
  if (days < 7) return DateFormat.E(context.l10n.localeName).format(local);
  return DateFormat.MMMd(context.l10n.localeName).format(local);
}
