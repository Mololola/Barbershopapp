import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../../../core/loading.dart';
import '../../../core/theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/profile.dart';
import '../../business/application/business_controller.dart';
import '../../business/domain/brand.dart';
import '../../worker/application/worker_controller.dart';
import '../../worker/domain/worker_leave_request.dart';
import '../application/messaging_controller.dart';
import '../domain/conversation.dart';
import '../domain/message.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _bodyController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(messagingActionControllerProvider.notifier).markConversationRead(widget.conversationId),
    );
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Called after every rebuild of the message list (initial load, a new
  /// realtime message) so the newest message is always in view, while a
  /// manual scroll up still works to read older history.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty) return;
    _bodyController.clear();
    await ref.read(messagingActionControllerProvider.notifier).sendMessage(widget.conversationId, body);
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(conversationMessagesProvider(widget.conversationId));
    final waiting = (ref.watch(messageOutboxProvider).value ?? const <Message>[])
        .where((m) => m.conversationId == widget.conversationId)
        .toList();
    final myId = ref.watch(currentProfileProvider).value?.id;
    final actionState = ref.watch(messagingActionControllerProvider);
    final conversation = ref.watch(conversationByIdProvider(widget.conversationId));
    final leaveRequest = conversation == null
        ? null
        : (ref.watch(pendingLeaveRequestsProvider).value ?? const [])
            .where((r) => r.workerProfileId == conversation.otherParticipantId)
            .firstOrNull;
    final other = conversation?.otherUsername;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: const BorderSide(color: AppColors.divider),
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: conversation == null ? null : _ChatHeader(conversation: conversation),
      ),
      body: Column(
        children: [
          if (leaveRequest != null) _LeaveRequestBanner(request: leaveRequest),
          Expanded(
            child: messages.when(
              loading: () => const LoadingView(),
              error: (error, _) => Center(child: Text(describeError(context.l10n, error))),
              data: (sent) {
                final list = [...sent, ...waiting];
                if (list.isEmpty) {
                  return Center(child: Text(context.l10n.noMessagesYet));
                }
                _scrollToBottom();
                final lastMine = list.lastIndexWhere((m) => m.senderId == myId);
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: list.length,
                  itemBuilder: (context, index) => _MessageItem(
                    message: list[index],
                    previous: index > 0 ? list[index - 1] : null,
                    next: index < list.length - 1 ? list[index + 1] : null,
                    isMine: list[index].senderId == myId,
                    showRead: index == lastMine,
                    waiting: index >= sent.length,
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: const BoxDecoration(
              color: AppColors.cardSurface,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bodyController,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: other == null ? context.l10n.message : context.l10n.messageTo(other),
                        filled: true,
                        fillColor: AppColors.chalk,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: fieldBorder.copyWith(
                          borderSide: const BorderSide(color: AppColors.brass, width: 1.5),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppColors.brass, foregroundColor: AppColors.onBrass),
                    tooltip: context.l10n.send,
                    icon: const Icon(Icons.send_rounded),
                    onPressed: actionState.isLoading ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Who you're talking to, in place of a "Conversation" title: photo, name,
/// and Barber or Shop when they are one. Opens their profile.
class _ChatHeader extends ConsumerWidget {
  const _ChatHeader({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherId = conversation.otherParticipantId;
    final role = ref.watch(profileByIdProvider(otherId)).value?.role;
    // The same fact the profile's Barber badge shows: a worker profile exists.
    final isBarber = role == AccountRole.customer && ref.watch(workerProfileByIdProvider(otherId)).value != null;
    final kind = isBarber ? context.l10n.kindBarber : (role == AccountRole.business ? context.l10n.kindShop : '');
    final avatarUrl = conversation.otherAvatarUrl;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/profile/$otherId'),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.brass.withValues(alpha: 0.2),
              foregroundColor: AppColors.brass,
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null ? Text(initialsOf(conversation.otherUsername)) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    conversation.otherUsername,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(color: AppColors.chalk, fontWeight: FontWeight.w600),
                  ),
                  Text('$kind${context.l10n.viewProfile}', style: textTheme.labelSmall?.copyWith(color: AppColors.brass)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One message, with a day marker above it when the day changes and its
/// time below the last message of a run. Messages from the same person
/// within a few minutes form one run, with the tail on its last bubble.
class _MessageItem extends StatelessWidget {
  const _MessageItem({
    required this.message,
    required this.previous,
    required this.next,
    required this.isMine,
    required this.showRead,
    this.waiting = false,
  });

  static const _runGap = Duration(minutes: 5);

  final Message message;
  final Message? previous;
  final Message? next;
  final bool isMine;

  /// True on your latest message: it says "Read" once they've seen it.
  final bool showRead;

  /// Written offline and not sent yet.
  final bool waiting;

  static bool _sameRun(Message earlier, Message later) =>
      earlier.senderId == later.senderId &&
      DateUtils.isSameDay(earlier.createdAt.toLocal(), later.createdAt.toLocal()) &&
      later.createdAt.difference(earlier.createdAt) < _runGap;

  static String _dayLabel(BuildContext context, DateTime at) {
    final local = at.toLocal();
    final now = DateTime.now();
    final days = DateUtils.dateOnly(now).difference(DateUtils.dateOnly(local)).inDays;
    if (days == 0) return context.l10n.today;
    if (days == 1) return context.l10n.yesterday;
    final format = local.year == now.year ? DateFormat.MMMd(context.l10n.localeName) : DateFormat.yMMMd(context.l10n.localeName);
    return format.format(local);
  }

  @override
  Widget build(BuildContext context) {
    final prev = previous;
    final after = next;
    final newDay = prev == null || !DateUtils.isSameDay(prev.createdAt.toLocal(), message.createdAt.toLocal());
    final startsRun = prev == null || !_sameRun(prev, message);
    final endsRun = after == null || !_sameRun(message, after);
    final textTheme = Theme.of(context).textTheme;
    const round = Radius.circular(18);
    const tail = Radius.circular(6);
    final read = isMine && showRead && message.readAt != null ? context.l10n.readMarker : '';

    return Column(
      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (newDay)
          Align(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.charcoal.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(_dayLabel(context, message.createdAt), style: textTheme.labelSmall?.copyWith(color: AppColors.steel)),
            ),
          ),
        Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
            child: Container(
              margin: EdgeInsets.only(top: startsRun && !newDay ? 8 : 2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? AppColors.charcoal : AppColors.cardSurface,
                border: isMine ? null : Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.only(
                  topLeft: round,
                  topRight: round,
                  bottomLeft: !isMine && endsRun ? tail : round,
                  bottomRight: isMine && endsRun ? tail : round,
                ),
              ),
              child: Text(
                message.body,
                style: textTheme.bodyMedium?.copyWith(color: isMine ? AppColors.chalk : AppColors.charcoal),
              ),
            ),
          ),
        ),
        if (endsRun)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
            child: Text(
              waiting
                  ? context.l10n.sending
                  : '${TimeOfDay.fromDateTime(message.createdAt.toLocal()).format(context)}$read',
              style: textTheme.labelSmall?.copyWith(color: AppColors.steel),
            ),
          ),
      ],
    );
  }
}

class _LeaveRequestBanner extends ConsumerWidget {
  const _LeaveRequestBanner({required this.request});

  final WorkerLeaveRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(leaveRequestControllerProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: AppColors.rust.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.workerAskedToLeave,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton(
                onPressed: actionState.isLoading
                    ? null
                    : () => ref.read(leaveRequestControllerProvider.notifier).reject(request),
                child: Text(context.l10n.reject),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.rust),
                onPressed: actionState.isLoading
                    ? null
                    : () => ref.read(leaveRequestControllerProvider.notifier).acknowledge(request),
                child: Text(context.l10n.confirmLeaving),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
