import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/loading.dart';
import '../../../core/status_message.dart';
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Messages'),
          bottom: TabBar(
            tabs: [
              _InboxTab(label: 'Personal', unread: _unread(personal)),
              _InboxTab(label: 'Business', unread: _unread(business)),
            ],
          ),
        ),
        body: conversations.when(
          loading: () => const LoadingView(caption: 'Loading conversations…'),
          error: (_, _) => Center(
            child: StatusMessage(
              icon: Icons.wifi_off_rounded,
              title: 'Couldn\'t load messages',
              message: 'Check your connection and try again.',
              actionLabel: 'Try again',
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
                  title: 'No conversations yet',
                  message: 'Find a barber or a friend and say hello from their profile.',
                  actionLabel: 'Find people',
                  onAction: () => context.push('/profile/search'),
                ),
              ),
              _ConversationList(
                conversations: business,
                empty: const StatusMessage(
                  icon: Icons.work_outline,
                  title: 'No work messages',
                  message: 'When a shop and a barber talk about work, it shows up here.',
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
      decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(10)),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w600),
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
              separatorBuilder: (_, _) => Divider(height: 1, indent: 80, color: Theme.of(context).colorScheme.outline),
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
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                foregroundColor: scheme.primary,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null ? Text(initialsOf(conversation.otherUsername)) : null,
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
                            conversation.lastMessageBody ?? 'Say hello 👋',
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

const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Today shows the time, this week the weekday, older the date.
String _whenLabel(BuildContext context, DateTime at) {
  final local = at.toLocal();
  final today = DateUtils.dateOnly(DateTime.now());
  final days = (today.difference(DateUtils.dateOnly(local)).inHours / 24).round();
  if (days <= 0) return TimeOfDay.fromDateTime(local).format(context);
  if (days == 1) return 'Yesterday';
  if (days < 7) return _weekdayShort[local.weekday - 1];
  return '${local.day} ${_monthShort[local.month - 1]}';
}
