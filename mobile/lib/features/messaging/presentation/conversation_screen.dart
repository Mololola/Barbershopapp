import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/loading.dart';
import '../../../core/theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../business/application/business_controller.dart';
import '../../worker/domain/worker_leave_request.dart';
import '../application/messaging_controller.dart';

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
    final myId = ref.watch(currentProfileProvider).value?.id;
    final actionState = ref.watch(messagingActionControllerProvider);
    final conversation = ref.watch(conversationByIdProvider(widget.conversationId));
    final leaveRequest = conversation == null
        ? null
        : (ref.watch(pendingLeaveRequestsProvider).value ?? const [])
            .where((r) => r.workerProfileId == conversation.otherParticipantId)
            .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Conversation')),
      body: Column(
        children: [
          if (leaveRequest != null) _LeaveRequestBanner(request: leaveRequest),
          Expanded(
            child: messages.when(
              loading: () => const LoadingView(),
              error: (error, _) => Center(child: Text('Error: $error')),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('No messages yet — say hello.'));
                }
                _scrollToBottom();
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final message = list[index];
                    final isMine = message.senderId == myId;
                    return Align(
                      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(message.body),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bodyController,
                      decoration: const InputDecoration(hintText: 'Message'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
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
          const Text(
            'This worker has asked to leave. They stay on staff until you confirm.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rust),
            onPressed: actionState.isLoading
                ? null
                : () => ref.read(leaveRequestControllerProvider.notifier).acknowledge(request),
            child: const Text('Confirm they\'re leaving'),
          ),
        ],
      ),
    );
  }
}
